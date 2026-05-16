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
      allow(SiteSetting).to receive(:mail_daily_summary_enabled).and_return(true)
      allow(SiteSetting).to receive(:mail_daily_summary_at).and_return("")
      allow(SiteSetting).to receive(:mail_daily_summary_day_of_week).and_return(0)
      allow(SiteSetting).to receive(:mail_daily_summary_debug_mode).and_return(false)
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

  it "does not enqueue before configured send time" do
    without_partial_double_verification do
      allow(SiteSetting).to receive(:mail_daily_summary_at).and_return("14:00")
    end

    allow(Time.zone).to receive(:now).and_return(Time.zone.parse("2026-04-22 13:30:00"))

    expect(job).not_to receive(:target_daily_users)
    expect(job).not_to receive(:target_weekly_users)
    expect(Jobs).not_to receive(:enqueue)

    job.execute({})
  end

  it "enqueues daily only after configured time when weekday does not match weekly day" do
    without_partial_double_verification do
      allow(SiteSetting).to receive(:mail_daily_summary_at).and_return("14:00")
      allow(SiteSetting).to receive(:mail_daily_summary_day_of_week).and_return(0)
    end

    allow(Time.zone).to receive(:now).and_return(Time.zone.parse("2026-04-22 14:30:00")) # Wednesday
    allow(job).to receive(:target_daily_users).and_return([default_user.id])
    expect(job).not_to receive(:target_weekly_users)
    allow(Jobs).to receive(:enqueue)

    job.execute({})

    expect(Jobs).to have_received(:enqueue).with(
      :user_daily_summary_email,
      { type: "daily_summary", user_id: default_user.id, frequency: "daily" },
    ).once
  end

  it "enqueues daily and weekly after configured time when weekday matches" do
    without_partial_double_verification do
      allow(SiteSetting).to receive(:mail_daily_summary_at).and_return("14:00")
      allow(SiteSetting).to receive(:mail_daily_summary_day_of_week).and_return(3)
    end

    allow(Time.zone).to receive(:now).and_return(Time.zone.parse("2026-04-22 14:30:00")) # Wednesday
    allow(job).to receive(:target_daily_users).and_return([default_user.id])
    allow(job).to receive(:target_weekly_users).and_return([explicit_weekly_user.id])
    allow(Jobs).to receive(:enqueue)

    job.execute({})

    expect(Jobs).to have_received(:enqueue).with(
      :user_daily_summary_email,
      { type: "daily_summary", user_id: default_user.id, frequency: "daily" },
    ).once
    expect(Jobs).to have_received(:enqueue).with(
      :user_daily_summary_email,
      { type: "daily_summary", user_id: explicit_weekly_user.id, frequency: "weekly" },
    ).once
  end
end
