# frozen_string_literal: true

module ::MailDailySummary
  PLUGIN_NAME = "mail-daily-summary"
  UNSUBSCRIBE = "mail_daily_summary"

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace MailDailySummary
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
