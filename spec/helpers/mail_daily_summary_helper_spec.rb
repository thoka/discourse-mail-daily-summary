# frozen_string_literal: true

require "rails_helper"
require_relative "../../app/helpers/mail_daily_summary_helper"

describe MailDailySummaryHelper do
  let(:helper_instance) { Class.new { include MailDailySummaryHelper }.new }

  describe "#daily_summary_excerpt_data" do
    fab!(:list_post) do
      Fabricate(
        :post,
        raw: <<~RAW,
          * This is a very long first list item with many words to make the excerpt exceed the configured limit
          * This is a very long second list item with many words to keep the total excerpt text length high
          * This is a very long third list item to ensure the fallback algorithm is exercised
        RAW
      )
    end

    fab!(:word_boundary_post) { Fabricate(:post, raw: "one two three four five six seven") }

    before do
      without_partial_double_verification do
        allow(SiteSetting).to receive(:mail_daily_summary_min_excerpt_length).and_return(20)
      end
    end

    it "falls back to plain text with ellipsis when paragraph extraction exceeds max" do
      maximum_length = 40

      without_partial_double_verification do
        allow(SiteSetting).to receive(:mail_daily_summary_max_excerpt_length).and_return(maximum_length)
      end

      data = helper_instance.send(:daily_summary_excerpt_data, list_post)

      expect(data[:truncated]).to eq(true)
      expect(data[:html]).to end_with("…")
      expect(data[:html]).not_to include("<ul")
      expect(data[:html].length).to be < maximum_length
    end

    it "truncates on a word boundary in fallback mode" do
      without_partial_double_verification do
        allow(SiteSetting).to receive(:mail_daily_summary_max_excerpt_length).and_return(15)
      end

      data = helper_instance.send(:daily_summary_excerpt_data, word_boundary_post)

      expect(data[:html]).to eq("one two…")
      expect(data[:html]).to end_with("…")
      expect(data[:html].length).to be < 15
    end

    it "uses plain-text fallback when min is 0 and max is set" do
      without_partial_double_verification do
        allow(SiteSetting).to receive(:mail_daily_summary_min_excerpt_length).and_return(0)
        allow(SiteSetting).to receive(:mail_daily_summary_max_excerpt_length).and_return(40)
      end

      data = helper_instance.send(:daily_summary_excerpt_data, list_post)

      expect(data[:truncated]).to eq(true)
      expect(data[:html]).to end_with("…")
      expect(data[:html]).not_to include("<ul")
      expect(data[:html].length).to be < 40
    end
  end
end
