# frozen_string_literal: true

require "rails_helper"
require_relative "../../app/jobs/scheduled/enqueue_mail_daily_summary"

describe Jobs::EnqueueMailDailySummary do
  fab!(:default_user) { Fabricate(:user) }
  fab!(:explicit_daily_user) { Fabricate(:user) }
  fab!(:explicit_weekly_user) { Fabricate(:user) }

  let(:job) { described_class.new }

  before do
    without_partial_double_verification do
      allow(SiteSetting).to receive(:mail_daily_summary_enable_as_default).and_return(true)
      allow(SiteSetting).to receive(:mail_daily_summary_frequency).and_return("daily")
      allow(SiteSetting).to receive(:must_approve_users?).and_return(false)
    end
  end

  def set_frequency(user, value)
    user.custom_fields["user_mail_summary_frequency"] = value
    user.save_custom_fields(true)
  end

  def set_last_sent_at(user, time)
    user.custom_fields["user_mail_summary_last_sent_at"] = time.to_s
    user.save_custom_fields(true)
  end

  it "daily target includes default users when site default is daily" do
    without_partial_double_verification do
      allow(SiteSetting).to receive(:mail_daily_summary_frequency).and_return("daily")
    end

    set_frequency(explicit_daily_user, "daily")
    set_frequency(explicit_weekly_user, "weekly")

    ids = job.target_daily_users

    expect(ids).to include(default_user.id)
    expect(ids).to include(explicit_daily_user.id)
    expect(ids).not_to include(explicit_weekly_user.id)
  end

  it "daily target includes only explicit daily overrides when site default is weekly" do
    without_partial_double_verification do
      allow(SiteSetting).to receive(:mail_daily_summary_frequency).and_return("weekly")
    end

    set_frequency(explicit_daily_user, "daily")
    set_frequency(explicit_weekly_user, "weekly")

    ids = job.target_daily_users

    expect(ids).to include(explicit_daily_user.id)
    expect(ids).not_to include(default_user.id)
    expect(ids).not_to include(explicit_weekly_user.id)
  end

  it "weekly target includes default users when site default is weekly" do
    without_partial_double_verification do
      allow(SiteSetting).to receive(:mail_daily_summary_frequency).and_return("weekly")
    end

    set_frequency(explicit_daily_user, "daily")
    set_frequency(explicit_weekly_user, "weekly")

    ids = job.target_weekly_users

    expect(ids).to include(default_user.id)
    expect(ids).to include(explicit_weekly_user.id)
    expect(ids).not_to include(explicit_daily_user.id)
  end

  it "respects last_sent_at threshold for daily and weekly" do
    without_partial_double_verification do
      allow(SiteSetting).to receive(:mail_daily_summary_frequency).and_return("daily")
    end
    set_last_sent_at(default_user, 2.hours.ago)

    daily_ids = job.target_daily_users
    expect(daily_ids).not_to include(default_user.id)

    without_partial_double_verification do
      allow(SiteSetting).to receive(:mail_daily_summary_frequency).and_return("weekly")
    end
    set_last_sent_at(default_user, 2.days.ago)

    weekly_ids = job.target_weekly_users
    expect(weekly_ids).not_to include(default_user.id)
  end
end
