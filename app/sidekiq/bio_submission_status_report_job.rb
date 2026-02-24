# frozen_string_literal: true

require 'csv'
require 'reports/uploader'

class BioSubmissionStatusReportJob
  include Sidekiq::Job

  BATCH_SIZE = 100

  HEADER_COLUMNS = ['UUID', 'Lighthouse status', 'Lighthouse updated at',
                    'CMP status', 'CMP updated at', 'Packet ID'].freeze

  def perform
    return unless Flipper.enabled?(:bio_submission_status_report_enabled) && FeatureFlipper.send_email?

    report_folder = "tmp/bio_submission_reports/#{jid}"
    FileUtils.mkdir_p(report_folder)

    s3_links = {}

    form_types.each do |form_type|
      link = generate_report(form_type, report_folder)
      s3_links[form_type] = link if link.present?
    rescue => e
      Rails.logger.error("BioSubmissionStatusReportJob: Error generating report for #{form_type}: #{e.message}")
    end

    BioSubmissionStatusReportMailer.build(s3_links).deliver_now if s3_links.present?
  ensure
    FileUtils.rm_rf(report_folder) if report_folder
  end

  private

  def form_types
    Array(Settings.reports&.bio_submission_status&.form_types).compact
  end

  def generate_report(form_type, report_folder)
    attempts = FormSubmissionAttempt
               .joins(:form_submission)
               .where(form_submissions: { form_type: })
               .where.not(form_submissions: { saved_claim_id: nil })
               .where('form_submission_attempts.created_at >= ?', 90.days.ago)
               .order(created_at: :desc)

    cmp_statuses = fetch_cmp_statuses(attempts)

    report_path = build_csv(form_type, attempts, cmp_statuses, report_folder)
    Reports::Uploader.get_s3_link(report_path)
  end

  def fetch_cmp_statuses(attempts)
    return {} unless CentralMail::Service.service_is_up?

    uuids = attempts.where.not(benefits_intake_uuid: nil).pluck(:benefits_intake_uuid)
    return {} if uuids.blank?

    statuses = {}
    cmp_service = CentralMail::Service.new

    uuids.each_slice(BATCH_SIZE) do |batch|
      response = cmp_service.status(batch)
      parsed = JSON.parse(response.body).flatten
      parsed.each { |entry| statuses[entry['uuid']] = parse_cmp_entry(entry) }
    end

    statuses
  rescue => e
    Rails.logger.warn("BioSubmissionStatusReportJob: CMP status fetch failed: #{e.message}")
    {}
  end

  def parse_cmp_entry(entry)
    # NOTE: 'veteranId' is actually the CM Portal Packet ID (naming is confusing but that's the API design)
    packet_id = entry['packets']&.first&.dig('veteranId')
    {
      status: entry['status'],
      last_updated: entry['lastUpdated'],
      packet_id:
    }
  end

  def build_csv(form_type, attempts, cmp_statuses, report_folder)
    total = attempts.size
    expected_annual = expected_annual_submissions(form_type)
    error_count = attempts.count { |a| a.aasm_state == 'failure' }
    canary_pct = expected_annual.positive? ? ((total.to_f / expected_annual) * 100).round(1) : 0

    filename = "#{report_folder}/#{form_type.gsub('/', '_')}_#{Time.zone.today}.csv"

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
        cmp[:packet_id]
      ]
    end
  end

  def expected_annual_submissions(form_type)
    config = Settings.reports&.bio_submission_status&.expected_annual_submissions
    value = config.respond_to?(:[]) ? config[form_type] : nil
    value.to_i
  end
end
