# frozen_string_literal: true

require 'sidekiq'
require 'appeals_api/upload_error'
require 'appeals_api/sidekiq_retry_notifier'
require 'central_mail/utilities'
require 'central_mail/service'
require 'pdf_info'
require 'sidekiq/monitored_worker'

module AppealsApi
  class NoticeOfDisagreementPdfSubmitJob
    include Sidekiq::Worker
    include Sidekiq::MonitoredWorker
    include CentralMail::Utilities
    include AppealsApi::CharacterUtilities

    def perform(id, version = 'V1')
      notice_of_disagreement = NoticeOfDisagreement.find(id)

      begin
        stamped_pdf = PdfConstruction::Generator.new(notice_of_disagreement, version: version).generate
        notice_of_disagreement.update_status!(status: 'submitting')
        upload_to_central_mail(notice_of_disagreement, stamped_pdf)
        File.delete(stamped_pdf) if File.exist?(stamped_pdf)
      rescue AppealsApi::UploadError => e
        handle_upload_error(notice_of_disagreement, e)
      rescue => e
        notice_of_disagreement.update_status!(status: 'error', code: e.class.to_s, detail: e.message)
        Rails.logger.error("#{self.class} error: #{e}")
        raise
      end
    end

    def retry_limits_for_notification
      [2, 5, 6, 10, 14, 17, 20]
    end

    def notify(retry_params)
      SidekiqRetryNotifier.notify!(retry_params)
    end

    private

    def upload_to_central_mail(notice_of_disagreement, pdf_path)
      metadata = {
        'veteranFirstName' => transliterate_for_centralmail(notice_of_disagreement.veteran_first_name),
        'veteranLastName' => transliterate_for_centralmail(notice_of_disagreement.veteran_last_name),
        'fileNumber' => notice_of_disagreement.file_number.presence || notice_of_disagreement.ssn,
        'zipCode' => notice_of_disagreement.zip_code_5,
        'source' => "Appeals-NOD-#{notice_of_disagreement.consumer_name}",
        'uuid' => notice_of_disagreement.id,
        'hashV' => Digest::SHA256.file(pdf_path).hexdigest,
        'numberAttachments' => 0,
        'receiveDt' => receive_date(notice_of_disagreement),
        'numberPages' => PdfInfo::Metadata.read(pdf_path).pages,
        'docType' => '10182',
        'lob' => notice_of_disagreement.lob
      }
      body = { 'metadata' => metadata.to_json, 'document' => to_faraday_upload(pdf_path, '10182-document.pdf') }
      process_response(CentralMail::Service.new.upload(body), notice_of_disagreement, metadata)
    end

    def process_response(response, notice_of_disagreement, metadata)
      if response.success? || response.body.match?(NON_FAILING_ERROR_REGEX)
        notice_of_disagreement.update_status!(status: 'submitted')
        log_submission(notice_of_disagreement, metadata)
      else
        map_error(response.status, response.body, AppealsApi::UploadError)
      end
    end

    def receive_date(notice_of_disagreement)
      notice_of_disagreement
        .created_at
        .in_time_zone('Central Time (US & Canada)')
        .strftime('%Y-%m-%d %H:%M:%S')
    end

    def handle_upload_error(notice_of_disagreement, e)
      log_upload_error(notice_of_disagreement, e)
      notice_of_disagreement.update(status: 'error', code: e.code, detail: e.detail)

      if e.code == 'DOC201' || e.code == 'DOC202'
        notify(
          {
            'class' => self.class.name,
            'args' => [notice_of_disagreement.id],
            'error_class' => e.code,
            'error_message' => e.detail,
            'failed_at' => Time.zone.now
          }
        )
      else
        # allow sidekiq to retry immediately
        raise
      end
    end

    def log_upload_error(notice_of_disagreement, e)
      Rails.logger.error("#{notice_of_disagreement.class.to_s.gsub('::', ' ')}: Submission failure",
                         'source' => notice_of_disagreement.consumer_name,
                         'consumer_id' => notice_of_disagreement.consumer_id,
                         'consumer_username' => notice_of_disagreement.consumer_name,
                         'uuid' => notice_of_disagreement.id,
                         'code' => e.code,
                         'detail' => e.detail)
    end
  end
end
