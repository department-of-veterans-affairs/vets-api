# frozen_string_literal: true

require 'sidekiq'
require 'appeals_api/higher_level_review_pdf_constructor'
require 'appeals_api/upload_error'

module AppealsApi
  class HigherLevelReviewPdfSubmitJob
    include Sidekiq::Worker
    include CentralMail::Utilities

    def perform(higher_level_review_id, retries = 0)
      @retries = retries
      pdf_constructor = AppealsApi::HigherLevelReviewPdfConstructor.new(higher_level_review_id)
      pdf_path = pdf_constructor.fill_pdf
      higher_level_review = HigherLevelReview.find higher_level_review_id
      higher_level_review.processing!
      stamped_pdf = pdf_constructor.stamp_pdf(pdf_path, higher_level_review.consumer_name)
      upload_to_central_mail(higher_level_review_id, stamped_pdf)
    end

    def upload_to_central_mail(higher_level_review_id, pdf_path)
      higher_level_review = AppealsApi::HigherLevelReview.find higher_level_review_id
      metadata = {
        'veteranFirstName' => higher_level_review.auth_headers['first_name'],
        'veteranLastName' => higher_level_review.auth_headers['last_name'],
        'source' => higher_level_review.auth_headers['consumer_name'],
        'uuid' => higher_level_review.id,
        'hashV' => Digest::SHA256.file(pdf_path).hexdigest,
        'numberPages' => PdfInfo::Metadata.read(pdf_path).pages,
        'docType' => '20-0996'
      }
      body = {
        'metadata' => metadata,
        'document' => to_faraday_upload(pdf_path, '200996-document.pdf')
      }
      response = CentralMail::Service.new.upload(body)
      process_response(response, higher_level_review)
      log_submission(higher_level_review, metadata)
    rescue AppealsApi::UploadError => e
      retry_errors(e, higher_level_review)
    end

    def process_response(response, higher_level_review)
      if response.success? || response.body.match?(NON_FAILING_ERROR_REGEX)
        higher_level_review.submitted!
      else
        map_downstream_error(response.status, response.body, AppealsApi::UploadError)
      end
    end
  end
end
