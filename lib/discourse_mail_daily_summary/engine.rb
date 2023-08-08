module DiscourseMailDailySummary
  class Engine < ::Rails::Engine
    isolate_namespace DiscourseMailDailySummary

    config.after_initialize do

      require_dependency 'user_notifications'
      class ::UserNotifications

        def apply_notification_styles(email)
          email.html_part.body = Email::Styles.new(email.html_part.body.to_s).tap do |styles|
          styles.format_basic
          styles.format_html
          end.to_html
          email
        end

        def mailing_list(user, opts={})

          def debug(msg)
            if SiteSetting.mail_daily_summary_debug_mode 
              Rails.logger.info("MDS: #{msg}")
            end
          end

          debug("mailing_list for #{user.id}/#{user.email} (opts: #{opts})")

          prepend_view_path "plugins/discourse-mlm-daily-summary/app/views" ##TODO: change path when plugin name changes

          @since = opts[:since] || 1.day.ago
          @since_formatted = short_date(@since)

          debug("since: #{@since} ( #{@since_formatted} )")

          topics = Topic
            .joins(:posts)
            .includes(:posts)
            .for_digest(user, 100.years.ago)
            .where("posts.created_at > ?", @since)
            .order("posts.id")
 
          unless user.staff?
            topics = topics.where("posts.post_type <> ?", Post.types[:whisper])
          end

          @new_topics = topics.where("topics.created_at > ?", @since).uniq
          @existing_topics = topics.where("topics.created_at <= ?", @since).uniq
          @topics = topics.uniq

          debug("topics: #{@topics.pluck(:id)}")
          return if @topics.empty?

          build_summary_for(user)
          opts = {
            from_alias: I18n.t('user_notifications.mailing_list.from', site_name: SiteSetting.title),
            subject: I18n.t('user_notifications.mailing_list.subject_template', email_prefix: @email_prefix, date: @date),
            mailing_list_mode: true,
            add_unsubscribe_link: SiteSetting.mlm_daily_summary_add_unsubscribe_link,
            unsubscribe_url: "#{Discourse.base_url}/email/unsubscribe/#{@unsubscribe_key}",
          }

          apply_notification_styles(build_email(@user.email, opts))
        end
      end 

      # require_dependency 'user_serializer'
      # class ::UserSerializer
      #   attributes :user_mlm_daily_summary_enabled

      #   def user_mlm_daily_summary_enabled
      #     if !object.custom_fields["user_mlm_daily_summary_enabled"]
      #       object.custom_fields["user_mlm_daily_summary_enabled"] = false
      #       object.save
      #     end
      #     object.custom_fields["user_mlm_daily_summary_enabled"]
      #   end
      # end

      module ::Jobs
        class EnqueueMailDailySummary < Jobs::Scheduled
          @@interval = 1 # in minutes
          every @@interval.minute 

          def debug(msg)
            if SiteSetting.mail_daily_summary_debug_mode 
              Rails.logger.info("MDS: #{msg}")
            end
          end

          def times_in_interval?(time1,time2,interval)

            def parse_if_needed(t)
                return t if t.is_a?(Time)
                Time.parse(t)
            end 
            
            def as_minutes(t)
                t = parse_if_needed(t)
                60*t.hour + t.min
            end 
        
            t1 = as_minutes(time1)
            t2 = as_minutes(time2)
            return [ 
              (t1 - t2).abs , 
              (t1 + 24*60 - t2).abs,
              (t1 - t2 - 24*60).abs 
            ].min < interval
          end

          def execute(args)

            last_run_at = DB.query_single(<<~SQL, klass: self.class.name)
              SELECT started_at FROM scheduler_stats
                 WHERE name = :klass AND success = true
                 ORDER BY started_at DESC
              LIMIT 1
            SQL
            debug("last run: #{last_run_at}")

            compare_user_first_seen_hour = true

            scheduled_time = SiteSetting.mail_daily_summary_at
            current_time = Time.now
          
            if scheduled_time.length > 0
              debug("scheduled_time: #{scheduled_time}")
              debug("current_time: #{current_time}")
              debug("interval: #{@@interval}")
              
              compare_user_first_seen_hour = false

              if ! times_in_interval?(scheduled_time,current_time,@@interval)
                debug("waiting till #{scheduled_time} (current server time: #{current_time.strftime('%H:%M')}) ...")
                return
              end
            else
              if current_time.min > @@interval 
                debug("waiting till next hour (current server time: #{current_time.strftime('%H:%M')}) ...")
                return
              end
            end 

            debug("------------------- Enqueue Daily Summary -------------------")
            t = target_user_ids(compare_user_first_seen_hour)
            debug("target_users: #{t}")
            t.each do |user_id|
              Jobs.enqueue(:user_email, type: :mailing_list, user_id: user_id) 
            end
          end

          def target_user_ids(compare_hour = true, repair_problems = true)

            repair_problem_64661_33 if SiteSetting.mail_daily_summary_debug_mode # repair only, if a report will be shown

            enabled_ids = UserCustomField.where(name: "user_mlm_daily_summary_enabled", value: "true").pluck(:user_id)
            users = User.real
                .activated
                .not_suspended
                .not_silenced
                .joins(:user_option)
                .where(id: enabled_ids)
                .where(staged: false)
                .where("#{!SiteSetting.must_approve_users?} OR approved OR moderator OR admin")
                .where("COALESCE(first_seen_at, '2010-01-01') <= CURRENT_TIMESTAMP - '23 HOURS'::INTERVAL") # don't send unless you've been around for a day already
            
            users = users.where("date_part('hour', first_seen_at) = date_part('hour', CURRENT_TIMESTAMP)") if compare_hour  # where the hour of first_seen_at is the same as the current hour

            users.pluck(:id)
          end

          def repair_problem_64661_33
              # see https://meta.discourse.org/t/64761/33
              not_yet_enabled_ids = UserCustomField.where(name: "user_mlm_daily_summary_enabled", value: "t").pluck(:user_id)
              if not_yet_enabled_ids.length > 0
                debug("fixing users with wrong option: #{not_yet_enabled_ids}")
                ## todo: it would be better, to send a message to admins about the fixed problem and run this once at startup of this plugin
                UserCustomField.where(name: "user_mlm_daily_summary_enabled", value: "t").update(value: "true")
              end
          end
        end
      end
    end
  end
end
