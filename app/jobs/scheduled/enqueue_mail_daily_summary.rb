# frozen_string_literal: true
module Jobs
  class EnqueueMailDailySummary < Jobs::Scheduled
    @@interval = 0.25
    every @@interval.minute

    def debug(msg)
      puts "🔴EMDS: #{msg}"
      Rails.logger.warn("MDS: #{msg}") if SiteSetting.mail_daily_summary_debug_mode
    end

    def today_at(time)
      hour, minute = time.split(":").map(&:to_i)
      Time.new.change(hour: hour, min: minute, usec: 0)
    end

    def execute(args)
      return unless SiteSetting.mail_daily_summary_enabled

      scheduled_time = SiteSetting.mail_daily_summary_at

      last_run_at =
        begin
          Time.parse(SiteSetting.mail_daily_summary_last_run_at)
        rescue StandardError
          nil
        end

      current_time = Time.now

      if scheduled_time.length > 0
        scheduled_time = today_at(scheduled_time)

        debug "last_run_at: #{last_run_at}, current_time: #{current_time}, scheduled_at: #{scheduled_time}"

        if last_run_at
          last_day_run = last_run_at.change(hour: 0, min: 0, sec: 0, usec: 0)
          current_day = current_time.change(hour: 0, min: 0, sec: 0, usec: 0)

          if current_day <= last_day_run
            debug("allready run today")
            return
          end
          if current_time < scheduled_time
            debug("waiting for scheduled time")
            return
          end

          since = [last_run_at, scheduled_time - 1000.day].max
        else
          return if current_time < scheduled_time
          since = scheduled_time - 1.day
        end

        compare_user_first_seen_hour = false
      else
        compare_user_first_seen_hour = true
        return if last_run_at && last_run_at.hour == current_time.hour

        c = current_time
        since = Time.new.change min: 0, sec: 0, usec: 0
      end

      SiteSetting.mail_daily_summary_last_run_at = current_time.to_s

      t = target_user_ids(compare_user_first_seen_hour)
      debug("since: #{since} target_users: #{t}")

      t.each do |user_id|
        opts = { type: "daily_summary", user_id: user_id, since: since.to_s }
        Jobs.enqueue(:user_daily_summary_email, opts)
      end
    end

    def target_user_ids(compare_hour = true)
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

      debug("users before filter: #{users.pluck(:id)}")
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

      users =
        users.where(
          "date_part('hour', first_seen_at) = date_part('hour', CURRENT_TIMESTAMP)",
        ) if compare_hour # where the hour of first_seen_at is the same as the current hour
      users = users.pluck(:id)

      users += MailDailySummary.auto_enabled_users
      users.uniq
    end
  end
end
