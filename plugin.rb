# name: discourse-mail-daily-summary
# about: Send a daily summary email.
# version: 0.0.6
# author: Thomas Kalka thomas.kalka@gmail.com
# url: https://www.github.com/thoka/discourse-mail-daily-summary

# this is a fork of Joe Buhlig's discourse-mlm-daily-summary with additional features
# https://www.github.com/joebuhlig/discourse-mlm-daily-summary

enabled_site_setting :mail_daily_summary_enabled

DiscoursePluginRegistry.serialized_current_user_fields << "user_mlm_daily_summary_enabled"

load File.expand_path('../lib/discourse_mail_daily_summary/engine.rb', __FILE__)

after_initialize do
  # TODO change name? this name is historical
  User.register_custom_field_type('user_mlm_daily_summary_enabled', :boolean) 
  register_editable_user_custom_field :user_mlm_daily_summary_enabled
end
