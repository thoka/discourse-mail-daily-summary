# name: discourse-mail-daily-summary
# about: Send a daily summary email.
# version: 0.0.10
# authors: Thomas Kalka
# url: https://www.github.com/thoka/discourse-mail-daily-summary

# this is a fork of Joe Buhlig's discourse-mlm-daily-summary with additional features
# https://www.github.com/joebuhlig/discourse-mlm-daily-summary

enabled_site_setting :mail_daily_summary_enabled

DiscoursePluginRegistry.serialized_current_user_fields << "user_mlm_daily_summary_enabled"

after_initialize do
  require_relative "lib/discourse_mail_daily_summary/user_notifications_extension.rb"
  require_relative "lib/discourse_mail_daily_summary/engine.rb"

  require_relative "app/jobs/regular/user_daily_summary_email.rb"
  require_relative "app/jobs/scheduled/enqueue_mail_daily_summary.rb"

  require_relative "app/helpers/helper.rb"

  # TODO change name? this name is historical
  User.register_custom_field_type("user_mlm_daily_summary_enabled", :boolean)
  register_editable_user_custom_field :user_mlm_daily_summary_enabled

  reloadable_patch do |plugin|
    UserNotifications.prepend MailDailySummary::UserNotificationsExtension
    UserNotifications.helper DiscourseMailDailySummary::Helper
  end

  Email::Styles.register_plugin_style do |fragment|
    @fragment = fragment
    def style(selector, style = nil, dm = nil)
      @fragment
        .css(selector)
        .each do |element|
          element[:style] = style if style
          element[:dm] = dm if dm
        end
    end

    # .header style="padding:10px 10px;background-color:#ffffff"

    # .daily-summary-header a "color:#006699;font-size:22px;text-decoration:none;"

    style(".daily-summary-topic-list", dm: "header")

    style(
      ".daily-summary",
      "line-height:1.4;text-align:left;line-height:1.4;text-align:left;font-size:14px;font-family:Helvetica,Arial,sans-serif",
      "text-color",
    )

    style(
      ".daily-summary-topic-header",
      "-moz-hyphens:auto;-webkit-hyphens:auto;border-collapse:collapse!important;color:#0a0a0a;hyphens:auto;line-height:1.3;margin:0;padding:0;vertical-align:top;word-wrap:normal",
      "text-color",
    )

    style(".daily-summary-topic-header h3", "padding: 20px 20px 10px; margin: 0", "text-color")

    style(
      ".daily-summary-topic-content",
      "border-left: 20px solid #eee; border-right: 20px solid #eee; border-bottom: 10px solid #eee; padding: 10px 10px;background: #fff",
      "text-color",
    )

    style(".daily-summary-topic-content p", "font-size: 15px")
  end
end
