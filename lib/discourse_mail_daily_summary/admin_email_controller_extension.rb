# frozen_string_literal: true

module MailDailySummary
  module AdminEmailControllerExtension
    def preview_digest
      return super unless SiteSetting.mail_daily_summary_preview_uses_daily_summary

      params.require(:last_seen_at)
      params.require(:username)

      user = User.find_by_username(params[:username])
      raise Discourse::InvalidParameters unless user

      message = UserNotifications.daily_summary(user, since: params[:last_seen_at])

      if message
        renderer = Email::Renderer.new(message)
        render json: MultiJson.dump(html_content: renderer.html, text_content: renderer.text)
      else
        render json: { errors: ["No content available for preview"] }, status: :unprocessable_entity
      end
    end

    def send_digest
      return super unless SiteSetting.mail_daily_summary_preview_uses_daily_summary

      params.require(:last_seen_at)
      params.require(:username)
      params.require(:email)
      user = User.find_by_username(params[:username])
      raise Discourse::InvalidParameters unless user

      message, skip_reason =
        UserNotifications.public_send(
          :daily_summary,
          user,
          since: params[:last_seen_at],
          skip_unsubscribe_links: true,
        )

      if message
        message.to = params[:email]

        begin
          Email::Sender.new(message, :daily_summary).send
          render json: success_json
        rescue => e
          render json: { errors: [e.message] }, status: :unprocessable_entity
        end
      else
        render json: { errors: skip_reason }
      end
    end
  end
end