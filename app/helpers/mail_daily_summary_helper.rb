# frozen_string_literal: true

module DiscourseMailDailySummary
  module MailDailySummaryHelper
    def daily_summary_topic(topic, count)
      render(partial: "daily_summary_topic", locals: { topic: topic })
    end
  end
end
