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

    def perform(id, retries = 0, version = 'V1')
      @retries = retries
      notice_of_disagreement = NoticeOfDisagreement.find(id)

      begin
        notice_of_disagreement.update_status!(status: 'submitting')
        stamped_pdf = PdfConstruction::Generator.new(notice_of_disagreement, version: version).generate
        upload_to_central_mail(notice_of_disagreement, stamped_pdf)
        File.delete(stamped_pdf) if File.exist?(stamped_pdf)
      rescue => e
        notice_of_disagreement.update_status!(status: 'error', code: e.class.to_s, detail: e.message)
        raise
      end
    end

    def retry_limits_for_notification
      [2, 5]
    end

    def notify(retry_params)
      SidekiqRetryNotifier.notify!(retry_params)
    end

    private

    def upload_to_central_mail(notice_of_disagreement, pdf_path)
      metadata = {
        'veteranFirstName' => notice_of_disagreement.veteran_first_name,
        'veteranLastName' => notice_of_disagreement.veteran_last_name,
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
      process_response(CentralMail::Service.new.upload(body), notice_of_disagreement)
      log_submission(notice_of_disagreement, metadata)
    rescue AppealsApi::UploadError => e
      e.detail = "#{e.detail} (retry attempt #{@retries})"
      retry_errors(e, notice_of_disagreement)
    end

    def process_response(response, notice_of_disagreement)
      if response.success? || response.body.match?(NON_FAILING_ERROR_REGEX)
        notice_of_disagreement.update_status!(status: 'submitted')
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
  end
end
