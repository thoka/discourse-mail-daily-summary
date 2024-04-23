module DiscourseMailDailySummary
  class Engine < ::Rails::Engine
    isolate_namespace DiscourseMailDailySummary

    config.after_initialize do
      require_dependency "user_notifications"
      class ::UserNotifications
        def daily_summary(user, opts = {})
          def debug(msg)
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
          @@interval = 5 # in minutes
          every @@interval.minute

          def debug(msg)
            Rails.logger.warn("MDS: #{msg}") if SiteSetting.mail_daily_summary_debug_mode
          end

          def times_in_interval?(time1, time2, interval)
            def parse_if_needed(t)
              return t if t.is_a?(Time)
              Time.parse(t)
            end

            def as_minutes(t)
              t = parse_if_needed(t)
              60 * t.hour + t.min
            end

            t1 = as_minutes(time1)
            t2 = as_minutes(time2)
            [(t1 - t2).abs, (t1 + 24 * 60 - t2).abs, (t1 - t2 - 24 * 60).abs].min < interval
          end

          def execute(args)
            if false
              last_run_at = DB.query_single(<<~SQL, klass: self.class.name)
                SELECT started_at FROM scheduler_stats
                  WHERE name = :klass AND success = true
                  ORDER BY started_at DESC
                LIMIT 1
              SQL
              debug("last run: #{last_run_at}")
            end

            compare_user_first_seen_hour = true

            scheduled_time = SiteSetting.mail_daily_summary_at

            begin
              last_run_at = Time.parse(SiteSetting.mail_daily_summary_last_run_at)
            rescue StandardError
              last_run_at = 1.day.ago
            end

            current_time = Time.now

            return if current_time - last_run_at < @@interval * 60 * 2

            if scheduled_time.length > 0
              compare_user_first_seen_hour = false

              if !times_in_interval?(scheduled_time, current_time, @@interval)
                debug(
                  "waiting for scheduled_time: #{scheduled_time} (current server time: #{current_time.strftime("%H:%M")}, interval: #{@@interval})",
                )
                return
              end
            else
              if current_time.min > @@interval
                debug(
                  "waiting till next hour (current server time: #{current_time.strftime("%H:%M")}) ...",
                )
                return
              end
            end

            debug("------------------- Enqueue Daily Summary -------------------")

            SiteSetting.mail_daily_summary_last_run_at = current_time.to_s

            t = target_user_ids(compare_user_first_seen_hour)
            debug("target_users: #{t}")

            t.each do |user_id|
              opts = {
                type: :daily_summary,
                user_id: user_id,
                # since: last_run_at,
                reject_reason: last_run_at.to_s, # TODO: this is a hack, since no other option survives
              }
              Jobs.enqueue(:user_email, opts)
            end
          end

          def target_user_ids(compare_hour = true, repair_problems = true)
            enabled_ids =
              UserCustomField.where(
                name: "user_mlm_daily_summary_enabled",
                value: %w[true t],
              ).pluck(:user_id)
            users =
              User
                .real
                .activated
                .not_suspended
                .not_silenced
                .joins(:user_option)
                .where(id: enabled_ids)
                .where(staged: false)
                .where("#{!SiteSetting.must_approve_users?} OR approved OR moderator OR admin")
                .where(
                  "COALESCE(first_seen_at, '2010-01-01') <= CURRENT_TIMESTAMP - '23 HOURS'::INTERVAL",
                ) # don't send unless you've been around for a day already

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
