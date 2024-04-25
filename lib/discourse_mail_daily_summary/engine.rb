module DiscourseMailDailySummary
  class Engine < ::Rails::Engine
    isolate_namespace DiscourseMailDailySummary

    config.after_initialize do
      require_dependency "user_notifications"
      class ::UserNotifications
        def daily_summary(user, opts = {})
          def debug(msg)
            puts "🔴UN: #{msg}"
            Rails.logger.warn("MDS: #{msg}") if SiteSetting.mail_daily_summary_debug_mode
          end

          debug("daily_summary for #{user.id}/#{user.email} (opts: #{opts})")

          prepend_view_path "plugins/discourse-mail-daily-summary/app/views"

          # @since = opts[:since] || 1.day.ago
          begin
            @since = Time.parse(opts[:reject_reason])
          rescue StandardError
            @since = 1.day.ago
          end

          @since_formatted = short_date(@since)

          debug("since: #{@since} ( #{@since_formatted} )")

          topics =
            Topic
              .joins(:posts)
              .includes(:posts)
              .for_digest(user, 100.years.ago)
              .where("posts.created_at > ?", @since)
              .order("posts.id")

          unless user.in_any_groups?(SiteSetting.whispers_allowed_groups_map)
            topics = topics.where("posts.post_type <> ?", Post.types[:whisper])
          end

          if DiscourseMailDailySummary.enabled_categories?
            topics =
              topics.where(
                category_id: DiscourseMailDailySummary.enabled_categories_including_subcategories,
              )
          end

          if SiteSetting.fixed_category_positions
            topics = topics.joins(:category).order("categories.position", :id, "posts.post_number")
          end

          @new_topics = topics.where("topics.created_at > ?", @since).uniq
          @existing_topics = topics.where("topics.created_at <= ?", @since).uniq
          @topics = topics.uniq

          debug("topics: #{@topics.pluck(:id)}")
          return if @topics.empty?

          build_summary_for(user)
          opts = {
            from_alias:
              I18n.t("user_notifications.daily_summary.from", site_name: SiteSetting.title),
            subject:
              I18n.t(
                "user_notifications.daily_summary.subject_template",
                email_prefix: @email_prefix,
                date: @date,
              ),
            mailing_list_mode: true,
            add_unsubscribe_link: SiteSetting.mail_daily_summary_add_unsubscribe_link,
            unsubscribe_url: "#{Discourse.base_url}/email/unsubscribe/#{@unsubscribe_key}", #TODO: is this correct?
          }

          build_email(@user.email, opts)
        end
      end

      module ::Jobs
        class EnqueueMailDailySummary < Jobs::Scheduled
          @@interval = 1 # in minutes
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
              # we have a scheduled time
              scheduled_time = today_at(scheduled_time)

              debug "last_run_at: #{last_run_at}, current_time: #{current_time}, scheduled_at: #{scheduled_time}"

              if last_run_at # and we know when we last ran
                # wait until we waited at least half a day since last run
                return unless last_run_at + 12.hours <= current_time
                # and its later than the scheduled time
                return unless current_time >= scheduled_time
                since = last_run_at
              else
                # we don't know when we last ran
                # wait until we're past the scheduled time
                return unless current_time >= scheduled_time
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
              opts = {
                type: :daily_summary,
                user_id: user_id,
                # since: since ,
                reject_reason: since.to_s, # TODO: this is a hack, since no other option survives
              }
              Jobs.enqueue(:user_email, opts)
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
                UserCustomField.where(
                  name: "user_mlm_daily_summary_enabled",
                  value: %w[true t],
                ).pluck(:user_id)
              users = users.where(id: enabled_ids)
            else
              disabled_ids =
                UserCustomField.where(
                  name: "user_mlm_daily_summary_enabled",
                  value: %w[false f],
                ).pluck(:user_id)
              users = users.where.not(id: disabled_ids)
            end

            users =
              users.where(
                "date_part('hour', first_seen_at) = date_part('hour', CURRENT_TIMESTAMP)",
              ) if compare_hour # where the hour of first_seen_at is the same as the current hour
            users = users.pluck(:id)

            users += DiscourseMailDailySummary.auto_enabled_users
            users.uniq
          end
        end
      end
    end
  end

  def self.enabled_categories
    SiteSetting.mail_daily_summary_enabled_categories.split("|").map(&:to_i)
  end

  def self.enabled_categories?
    enabled_categories.length > 0
  end

  def self.enabled_categories_including_subcategories
    enabled_categories + Category.where(parent_category_id: enabled_categories).pluck(:id)
  end

  def self.auto_enabled_users
    auto_enabled_groups = SiteSetting.mail_daily_summary_auto_enabled_groups_map
    GroupUser.where(group_id: auto_enabled_groups).pluck(:user_id).uniq
  end
end
