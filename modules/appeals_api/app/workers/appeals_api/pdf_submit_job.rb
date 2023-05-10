# frozen_string_literal: true

require 'sidekiq'
require 'appeals_api/upload_error'
require 'appeals_api/hlr_pdf_submit_wrapper'
require 'appeals_api/nod_pdf_submit_wrapper'
require 'appeals_api/sc_pdf_submit_wrapper'
require 'central_mail/utilities'
require 'central_mail/service'
require 'pdf_info'
require 'sidekiq/monitored_worker'

module AppealsApi
  class PdfSubmitJob
    include Sidekiq::Worker
    include Sidekiq::MonitoredWorker
    include CentralMail::Utilities
    include AppealsApi::CharacterUtilities

    APPEAL_WRAPPERS = {
      AppealsApi::HigherLevelReview => AppealsApi::HlrPdfSubmitWrapper,
      AppealsApi::NoticeOfDisagreement => AppealsApi::NodPdfSubmitWrapper,
      AppealsApi::SupplementalClaim => AppealsApi::ScPdfSubmitWrapper
    }.freeze

    # retryable EMMS API provided http response status codes
    # 401 Unauthorized - missing or incorrect token
    # 429 Too many requests (for a single GUID)
    # 500 Server Error
    # 503 Database Offline || SOLR Service Offline || Intake API is undergoing maintenance
    RETRYABLE_EMMS_RESP_STATUS_CODES = [401, 429, 500, 503].freeze

    # Retry for ~7 days
    sidekiq_options retry: 20, unique_for: 7.days

    def perform(appeal_id, appeal_class_str, pdf_version = 'v1')
      appeal_class = Object.const_get(appeal_class_str)
      appeal = appeal_wrapper(appeal_class).new(appeal_class.find(appeal_id))

      begin
        stamped_pdf = AppealsApi::PdfConstruction::Generator.new(appeal, pdf_version:).generate
        appeal.update_status!(status: 'submitting')
        upload_to_central_mail(appeal, stamped_pdf)
        File.delete(stamped_pdf) if File.exist?(stamped_pdf)
      rescue AppealsApi::UploadError => e
        handle_upload_error(appeal, e)
      rescue => e
        appeal.update_status!(status: 'error', code: e.class.to_s, detail: e.message)
        Rails.logger.error("#{self.class} - #{appeal_class} error: #{e}")
        raise
      end
    end

    def retry_limits_for_notification
      # Alert @ 30m, 4h, 1d, 3d, and 7d
      [6, 10, 14, 17, 20]
    end

    def notify(retry_params)
      AppealsApi::Slack::Messager.new(retry_params, notification_type: :error_retry).notify!
    end

    private

    def appeal_wrapper(appeal_class)
      APPEAL_WRAPPERS.fetch(appeal_class)
    end

    def upload_to_central_mail(appeal, pdf_path)
      metadata = appeal.metadata(pdf_path)
      body = { 'metadata' => metadata.to_json,
               'document' => to_faraday_upload(pdf_path, appeal.pdf_file_name) }
      process_response(CentralMail::Service.new.upload(body), appeal, metadata)
    end

    def process_response(response, appeal, metadata)
      if response.success?
        appeal.update_status!(status: 'submitted')
        log_submission(appeal, metadata)
      else
        map_error(response.status, response.body, AppealsApi::UploadError)
      end
    end

    def log_upload_error(appeal, e)
      Rails.logger.error("#{appeal.class.to_s.gsub('::', ' ')}: Submission failure",
                         'source' => appeal.consumer_name,
                         'consumer_id' => appeal.consumer_id,
                         'consumer_username' => appeal.consumer_name,
                         'uuid' => appeal.id,
                         'code' => e.code,
                         'detail' => e.detail)
    end

    def handle_upload_error(appeal, e)
      log_upload_error(appeal, e)
      appeal.update_status(status: 'error', code: e.code, detail: e.detail)

      # re-raise retryable EMMS errors so sidekick will retry
      raise if RETRYABLE_EMMS_RESP_STATUS_CODES.include?(e.upstream_http_resp_status)

      # non retryable error, eat the exception so sidekiq WON'T retry and slack notify
      notify(
        {
          'class' => self.class.name,
          'args' => [appeal.id, appeal.class.to_s, appeal.created_at.iso8601],
          'error_class' => e.code,
          'error_message' => e.detail,
          'failed_at' => Time.zone.now
        }
      )
    end
  end
end
