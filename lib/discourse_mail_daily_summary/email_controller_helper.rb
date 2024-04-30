# frozen_string_literal: true

module EmailControllerHelper
  class MailDailySummaryUnsubscriber < BaseEmailUnsubscriber
    def prepare_unsubscribe_options(controller)
      super(controller)

      controller.instance_variable_set(:@unsubscribe_mail_daily_summary, true)
      controller.instance_variable_set(
        :@current_mail_daily_summary_subscibed,
        key_owner.custom_fields[:user_mlm_daily_summary_enabled],
      )

      enabling_groups =
        key_owner.groups.pluck(:id) & SiteSetting.mail_daily_summary_auto_enabled_groups_map

      if enabling_groups.length > 0
        enabling_groups.map! { |id| Group.find(id)&.name }
        controller.instance_variable_set(:@mail_daily_summary_enabling_groups, enabling_groups)
      end
    end

    def unsubscribe(params)
      updated = super(params)

      if params[:unsubscribe_daily_summaries]
        key_owner.custom_fields[:user_mlm_daily_summary_enabled] = false
        key_owner.save_custom_fields
        updated = true
      end

      updated
    end
  end
end
