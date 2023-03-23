# frozen_string_literal: true

class AppealsApi::MonthlyStatsReport
  include Sidekiq::Worker
  include Sidekiq::MonitoredWorker
  include AppealsApi::ReportRecipientsReader

  sidekiq_options retry: 20, unique_for: 3.weeks

  def perform(end_date = Time.now.iso8601)
    return unless enabled?

    recipients = load_recipients(:stats_report_monthly)
    return if recipients.empty?

    date_to = Time.zone.parse(end_date).beginning_of_day
    date_from = (date_to - 1.month).beginning_of_day

    AppealsApi::StatsReportMailer.build(
      date_from:,
      date_to:,
      recipients:,
      subject: "Lighthouse appeals stats report for month starting #{date_from.strftime('%Y-%m-%d')}"
    ).deliver_now
  end

  def retry_limits_for_notification
    [20]
  end

  def notify(retry_params)
    AppealsApi::Slack::Messager.new(retry_params, notification_type: :error_retry).notify!
  end

  private

  def enabled?
    FeatureFlipper.send_email? && Flipper.enabled?(:decision_review_monthly_stats_report_enabled)
  end
end
