# frozen_string_literal: true
module Jobs
  class EnqueueMailDailySummary < Jobs::Scheduled
    @@interval = Rails.env.production? ? 5 : 0.25
    every @@interval.minute

    def debug(msg)
      return until SiteSetting.mail_daily_summary_debug_mode
      puts "🔴eMDS: #{msg}"
      Rails.logger.warn("eMDS: #{msg}")
    end

    def today_at(time, current_time = Time.zone.now)
      hour, minute = time.split(":").map(&:to_i)
      current_time.change(hour: hour, min: minute, sec: 0, usec: 0)
    end

    def scheduled_time_reached?(current_time)
      scheduled_time = SiteSetting.mail_daily_summary_at
      return true if scheduled_time.blank?

      current_time >= today_at(scheduled_time, current_time)
    end

    def execute(args)
      return unless SiteSetting.mail_daily_summary_enabled

      current_time = Time.zone.now

      unless scheduled_time_reached?(current_time)
        debug("waiting for scheduled time")
        return
      end

      debug("Starting enqueue cycle")

      # Process daily users
      daily_users = target_daily_users
      debug("Daily users to process: #{daily_users.count}")
      daily_users.each do |user_id|
        opts = { type: "daily_summary", user_id: user_id, frequency: "daily" }
        Jobs.enqueue(:user_daily_summary_email, opts)
      end

      # Process weekly users (only on the correct day)
      if current_time.wday == SiteSetting.mail_daily_summary_day_of_week
        weekly_users = target_weekly_users
        debug("Weekly users to process: #{weekly_users.count}")
        weekly_users.each do |user_id|
          opts = { type: "daily_summary", user_id: user_id, frequency: "weekly" }
          Jobs.enqueue(:user_daily_summary_email, opts)
        end
      else
        debug("waiting for the right day of week")
      end
    end

    def base_user_scope
      users =
        User
          .real
          .activated
          .not_suspended
          .not_silenced
          .joins(:user_option)
          .where(staged: false)
          .where("#{!SiteSetting.must_approve_users?} OR approved OR moderator OR admin")
          .where(
            "COALESCE(first_seen_at, '2010-01-01') <= CURRENT_TIMESTAMP - '23 HOURS'::INTERVAL",
          ) # don't send unless you've been around for a day already

      # Apply opt-in/out filter
      if !SiteSetting.mail_daily_summary_enable_as_default
        enabled_ids =
          UserCustomField.where(name: "user_mlm_daily_summary_enabled", value: %w[true t]).pluck(
            :user_id,
          )
        users = users.where(id: enabled_ids)
      else
        disabled_ids =
          UserCustomField.where(name: "user_mlm_daily_summary_enabled", value: %w[false f]).pluck(
            :user_id,
          )
        users = users.where.not(id: disabled_ids)
      end

      users
    end

    def target_daily_users
      users_due_for_frequency("daily", "1 day")
    end

    def target_weekly_users
      users_due_for_frequency("weekly", "7 days")
    end

    def users_due_for_frequency(frequency, interval)
      users = base_user_scope

      if SiteSetting.mail_daily_summary_frequency == frequency
        opposite_frequency = frequency == "daily" ? "weekly" : "daily"

        # Site default matches this frequency, so only exclude users who explicitly override to the opposite value.
        users =
          users.where(
            "NOT EXISTS (
              SELECT 1 FROM user_custom_fields frequency_cf
              WHERE frequency_cf.user_id = users.id
                AND frequency_cf.name = 'user_mail_summary_frequency'
                AND frequency_cf.value = ?
            )",
            opposite_frequency,
          )
      else
        # Site default does not match this frequency, so only include explicit overrides.
        users =
          users.where(
            "EXISTS (
              SELECT 1 FROM user_custom_fields frequency_cf
              WHERE frequency_cf.user_id = users.id
                AND frequency_cf.name = 'user_mail_summary_frequency'
                AND frequency_cf.value = ?
            )",
            frequency,
          )
      end

      users =
        users.where(
          "NOT EXISTS (
            SELECT 1 FROM user_custom_fields last_sent_cf
            WHERE last_sent_cf.user_id = users.id
              AND last_sent_cf.name = 'user_mail_summary_last_sent_at'
              AND last_sent_cf.value::timestamp > CURRENT_TIMESTAMP - ?::INTERVAL
          )",
          interval,
        )

      users.pluck(:id)
    end

    def target_user_ids(compare_hour = true)
      # Deprecated: kept for backwards compatibility if needed
      # New logic uses target_daily_users and target_weekly_users
      users = base_user_scope
      users = users.pluck(:id)
      users += MailDailySummary.auto_enabled_users
      users.uniq
    end
  end
end
