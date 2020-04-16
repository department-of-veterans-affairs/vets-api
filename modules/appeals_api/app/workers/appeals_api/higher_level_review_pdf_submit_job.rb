# frozen_string_literal: true

require 'sidekiq'
require 'appeals_api/higher_level_review_pdf_constructor'

module AppealsApi
  class HigherLevelReviewPdfSubmitJob
    include Sidekiq::Worker

    def perform(higher_level_review_id)
      pdf_constructor = AppealsApi::HigherLevelReviewPdfConstructor.new(higher_level_review_id)
      pdf_path = pdf_constructor.fill_pdf
      # set status to processing until the central mail upload
      HigherLevelReview.update(higher_level_review_id, status: 'processing')
      # send to central mail
    end

    def upload_to_central_mail(higher_level_review, pdf_path)
      body = {
        'metadata': {
          'veteranFirstName': higher_level_review.auth_headers['first_name'],
          'veteranLastName': higher_level_review.auth_headers['last_name'],
          'source': higher_level_review.auth_headers['consumer_name'],
          'uuid': higher_level_review.id,
          'hashV': Digest::SHA256.file(pdf_path).hexdigest,
          'numberPages': PdfInfo::Metadata.read(pdf_path).pages,
          'docType': '20-0996'
        },
        'document': to_faraday_upload(pdf_path)
      }
      CentralMail::Service.new.upload(body)
    end

    def to_faraday_upload(file_path)
      Faraday::UploadIO.new(
        file_path,
        Mime[:pdf].to_s
      )
    end
  end
end
