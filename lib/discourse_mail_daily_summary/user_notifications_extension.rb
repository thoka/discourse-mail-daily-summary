# frozen_string_literal: true

module MailDailySummary
  module UserNotificationsExtension
    def daily_summary(user, opts = {})
      def debug(msg)
        puts "🔴UN: #{msg}"
        Rails.logger.warn("MDS: #{msg}") if SiteSetting.mail_daily_summary_debug_mode
      end

      debug("daily_summary for #{user.id}/#{user.email} (opts: #{opts})")

      prepend_view_path "plugins/discourse-mail-daily-summary/app/views"

      @since = Time.parse(opts[:since])

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

      if MailDailySummary.enabled_categories?
        topics =
          topics.where(category_id: MailDailySummary.enabled_categories_including_subcategories)
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
        from_alias: I18n.t("user_notifications.daily_summary.from", site_name: SiteSetting.title),
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
end
