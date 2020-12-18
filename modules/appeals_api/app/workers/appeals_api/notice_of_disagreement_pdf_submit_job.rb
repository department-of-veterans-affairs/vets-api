# frozen_string_literal: true

require 'sidekiq'
require 'appeals_api/notice_of_disagreement_pdf_constructor'
require 'appeals_api/upload_error'
require 'central_mail/utilities'
require 'central_mail/service'
require 'pdf_info'

module AppealsApi
  class NoticeOfDisagreementPdfSubmitJob
    include Sidekiq::Worker
    include CentralMail::Utilities

    def perform(notice_of_disagreement_id, retries = 0)
      @retries = retries
      stamped_pdf = generate_pdf(notice_of_disagreement_id)
      upload_to_central_mail(notice_of_disagreement_id, stamped_pdf)
      File.delete(stamped_pdf) if File.exist?(stamped_pdf)
    end

    def generate_pdf(notice_of_disagreement_id)
      pdf_constructor = AppealsApi::NoticeOfDisagreementPdfConstructor.new(notice_of_disagreement_id)
      pdf_path = pdf_constructor.fill_pdf
      notice_of_disagreement = NoticeOfDisagreement.find notice_of_disagreement_id
      notice_of_disagreement.update!(status: 'submitting')
      inserted_text_pdf = pdf_constructor.insert_manual_fields(pdf_path)
      pdf_constructor.stamp_pdf(inserted_text_pdf, notice_of_disagreement.consumer_name)
    end

    def upload_to_central_mail(notice_of_disagreement_id, pdf_path)
      notice_of_disagreement = AppealsApi::NoticeOfDisagreement.find notice_of_disagreement_id
      metadata = {
        'veteranFirstName' => notice_of_disagreement.veteran_first_name,
        'veteranLastName' => notice_of_disagreement.veteran_last_name,
        'fileNumber' => notice_of_disagreement.file_number.presence || notice_of_disagreement.ssn,
        'zipCode' => '', # TODO: temporarily an empty string until we take in address info
        'source' => "Appeals-NOD-#{notice_of_disagreement.consumer_name}",
        'uuid' => notice_of_disagreement.id,
        'hashV' => Digest::SHA256.file(pdf_path).hexdigest,
        'numberAttachments' => 0,
        'receiveDt' => notice_of_disagreement.created_at.strftime('%Y-%m-%d %H:%M:%S'),
        'numberPages' => PdfInfo::Metadata.read(pdf_path).pages,
        'docType' => '10182'
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
        notice_of_disagreement.update!(status: 'submitted')
      else
        map_error(response.status, response.body, AppealsApi::UploadError)
      end
    end
  end
end
