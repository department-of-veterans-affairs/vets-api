# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'

# This alerts to slack so that we are more immediately aware of UNSUBMITTED records that somehow did not error
# but have also not been submitted to CMP - it's rare, but has happened.
class AppealsApi::DailyStuckRecordsReport
  include Sidekiq::Worker
  include Sidekiq::MonitoredWorker

  # Only retry for ~8 hours since the job runs daily
  sidekiq_options retry: 11, unique_for: 8.hours

  def perform
    return unless enabled?

    params = find_stuck_record_data(AppealsApi::HigherLevelReview) + \
             find_stuck_record_data(AppealsApi::NoticeOfDisagreement) + \
             find_stuck_record_data(AppealsApi::SupplementalClaim)

    return if params.empty?

    AppealsApi::Slack::Messager.new(params, notification_type: :stuck_record).notify!
  end

  def enabled?
    Flipper.enabled? :decision_review_daily_stuck_records_report_enabled
  end

  def retry_limits_for_notification
    [11]
  end

  def notify(retry_params)
    AppealsApi::Slack::Messager.new(retry_params, notification_type: :error_retry).notify!
  end

  private

  def find_stuck_record_data(klass)
    data = []
    klass.stuck_unsubmitted.select(:id, :status, :created_at).find_each do |record|
      data << record.attributes.compact.symbolize_keys.merge({ record_type: klass.name.demodulize })
    end
    data
  end
end
