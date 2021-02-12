# frozen_string_literal: true

require 'sidekiq'
require 'appeals_api/upload_error'
require 'central_mail/utilities'
require 'central_mail/service'
require 'pdf_info'

module AppealsApi
  class HigherLevelReviewPdfSubmitJob
    include Sidekiq::Worker
    include CentralMail::Utilities

    def perform(higher_level_review_id, retries = 0)
      higher_level_review = AppealsApi::HigherLevelReview.find(higher_level_review_id)

      begin
        @retries = retries
        stamped_pdf = AppealsApi::PdfConstruction::Generator.new(higher_level_review).generate
        higher_level_review.update!(status: 'submitting')
        upload_to_central_mail(higher_level_review, stamped_pdf)
        File.delete(stamped_pdf) if File.exist?(stamped_pdf)
      rescue => e
        higher_level_review.update!(status: 'error', code: e.class.to_s, detail: e.message)
        raise
      end
    end

    def upload_to_central_mail(higher_level_review, pdf_path)
      metadata = {
        'veteranFirstName' => higher_level_review.first_name,
        'veteranLastName' => higher_level_review.last_name,
        'fileNumber' => higher_level_review.file_number.presence || higher_level_review.ssn,
        'zipCode' => higher_level_review.zip_code_5,
        'source' => "Appeals-HLR-#{higher_level_review.consumer_name}",
        'uuid' => higher_level_review.id,
        'hashV' => Digest::SHA256.file(pdf_path).hexdigest,
        'numberAttachments' => 0,
        'receiveDt' => higher_level_review.created_at.strftime('%Y-%m-%d %H:%M:%S'),
        'numberPages' => PdfInfo::Metadata.read(pdf_path).pages,
        'docType' => '20-0996'
      }
      body = { 'metadata' => metadata.to_json, 'document' => to_faraday_upload(pdf_path, '200996-document.pdf') }
      process_response(CentralMail::Service.new.upload(body), higher_level_review)
      log_submission(higher_level_review, metadata)
    rescue AppealsApi::UploadError => e
      e.detail = "#{e.detail} (retry attempt #{@retries})"
      retry_errors(e, higher_level_review)
    end

    def process_response(response, higher_level_review)
      if response.success? || response.body.match?(NON_FAILING_ERROR_REGEX)
        higher_level_review.update!(status: 'submitted')
      else
        map_error(response.status, response.body, AppealsApi::UploadError)
      end
    end
  end
end
