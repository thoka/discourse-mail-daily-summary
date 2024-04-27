# frozen_string_literal: true

module Jobs
  class UserDailySummaryEmail < ::Jobs::UserEmail
    def message_for_email(user, post, type, notification, args = nil)
      puts "🔴🔴 #{user.id}/#{user.email} type: #{type} args: #{args}"
      args ||= {}

      email_token = args[:email_token]
      to_address = args[:to_address]

      if user.anonymous?
        return skip_message(SkippedEmailLog.reason_types[:user_email_anonymous_user])
      end

      if user.suspended?
        if !type.in?(%w[user_private_message account_suspended])
          return skip_message(SkippedEmailLog.reason_types[:user_email_user_suspended_not_pm])
        elsif post&.topic&.group_pm?
          return skip_message(SkippedEmailLog.reason_types[:user_email_user_suspended])
        end
      end

      return if user.staged

      email_args = {}

      # Make sure that mailer exists
      unless UserNotifications.respond_to?(type)
        raise Discourse::InvalidParameters.new("type=#{type}")
      end

      email_args[:email_token] = email_token if email_token.present?

      if !EmailLog::CRITICAL_EMAIL_TYPES.include?(type) &&
           user.user_stat.bounce_score >= SiteSetting.bounce_score_threshold
        return skip_message(SkippedEmailLog.reason_types[:exceeded_bounces_limit])
      end

      email_args[:since] = args[:since]

      message =
        EmailLog.unique_email_per_post(post, user) do
          UserNotifications.public_send(type, user, email_args)
        end

      # Update the to address if we have a custom one
      message.to = to_address if message && to_address.present?

      [message, nil]
    end
  end
end
