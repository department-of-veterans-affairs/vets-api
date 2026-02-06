# frozen_string_literal: true

require 'csv'
require 'reports/uploader'

class BioSubmissionStatusReportJob
  include Sidekiq::Job

  BATCH_SIZE = 100
  REPORT_FOLDER = 'tmp/bio_submission_reports'

  HEADER_COLUMNS = ['UUID', 'Lighthouse status', 'Lighthouse updated at',
                    'CMP status', 'CMP updated at', 'Packet ID'].freeze

  def perform
    return unless Flipper.enabled?(:bio_submission_status_report_enabled) && FeatureFlipper.send_email?

    FileUtils.mkdir_p(REPORT_FOLDER)

    s3_links = {}

    form_types.each do |form_type|
      s3_links[form_type] = generate_report(form_type)
    rescue => e
      Rails.logger.error("BioSubmissionStatusReportJob: Error generating report for #{form_type}: #{e.message}")
    end

    BioSubmissionStatusReportMailer.build(s3_links).deliver_now if s3_links.present?
  ensure
    FileUtils.rm_rf(REPORT_FOLDER)
  end

  private

  def form_types
    Settings.reports.bio_submission_status.form_types.to_a
  end

  def generate_report(form_type)
    attempts = FormSubmissionAttempt
               .joins(:form_submission)
               .where(form_submissions: { form_type: })
               .where('form_submission_attempts.created_at >= ?', 90.days.ago)
               .order(created_at: :desc)

    cmp_statuses = fetch_cmp_statuses(attempts)

    report_path = build_csv(form_type, attempts, cmp_statuses)
    Reports::Uploader.get_s3_link(report_path)
  end

  def fetch_cmp_statuses(attempts)
    return {} unless CentralMail::Service.service_is_up?

    uuids = attempts.filter_map(&:benefits_intake_uuid)
    return {} if uuids.blank?

    statuses = {}
    cmp_service = CentralMail::Service.new

    uuids.each_slice(BATCH_SIZE) do |batch|
      response = cmp_service.status(batch)
      parsed = JSON.parse(response.body).flatten
      parsed.each do |entry|
        statuses[entry['uuid']] = {
          status: entry['status'],
          last_updated: entry['lastUpdated']
        }
      end
    end

    statuses
  rescue => e
    Rails.logger.warn("BioSubmissionStatusReportJob: CMP status fetch failed: #{e.message}")
    {}
  end

  def build_csv(form_type, attempts, cmp_statuses)
    total = attempts.size
    expected_annual = expected_annual_submissions(form_type)
    error_count = attempts.count { |a| a.aasm_state == 'failure' }
    canary_pct = expected_annual.positive? ? ((total.to_f / expected_annual) * 100).round(1) : 0

    filename = "#{REPORT_FOLDER}/#{form_type.gsub('/', '_')}_#{Time.zone.today}.csv"

    CSV.open(filename, 'wb') do |csv|
      csv << ["#{form_type} Post-Go-Live Submission Tracker"]
      csv << []
      csv << ['Expected annual submissions', expected_annual, 'Canary']
      csv << ['Total submissions', total, "#{canary_pct}%"]
      csv << ['Number of Incomplete/Errors', error_count]
      csv << []
      csv << HEADER_COLUMNS

      write_data_rows(csv, attempts, cmp_statuses)
    end

    filename
  end

  def write_data_rows(csv, attempts, cmp_statuses)
    attempts.each do |attempt|
      cmp = cmp_statuses[attempt.benefits_intake_uuid] || {}
      csv << [
        attempt.benefits_intake_uuid,
        attempt.aasm_state,
        attempt.lighthouse_updated_at.to_s,
        cmp[:status],
        cmp[:last_updated],
        nil
      ]
    end
  end

  def expected_annual_submissions(form_type)
    Settings.reports.bio_submission_status.expected_annual_submissions[form_type].to_i
  end
end
