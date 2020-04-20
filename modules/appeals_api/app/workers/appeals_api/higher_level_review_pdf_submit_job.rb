# frozen_string_literal: true

require 'sidekiq'
require 'appeals_api/higher_level_review_pdf_constructor'
require 'appeals_api/upload_error'

module AppealsApi
  class HigherLevelReviewPdfSubmitJob
    include Sidekiq::Worker

    RETRIES = 3
    META_PART_NAME = 'metadata'
    DOC_PART_NAME = 'content'
    SUBMIT_DOC_PART_NAME = 'document'
    REQUIRED_KEYS = %w[veteranFirstName veteranLastName fileNumber zipCode].freeze
    FILE_NUMBER_REGEX = /^\d{8,9}$/.freeze
    INVALID_ZIP_CODE_ERROR_REGEX = /Invalid zipCode/.freeze
    MISSING_ZIP_CODE_ERROR_REGEX = /Missing zipCode/.freeze
    NON_FAILING_ERROR_REGEX = /Document already uploaded with uuid/.freeze
    INVALID_ZIP_CODE_ERROR_MSG = 'Invalid ZIP Code. ZIP Code must be 5 digits, ' \
      'or 9 digits in XXXXX-XXXX format. Specify \'00000\' for non-US addresses.'
    MISSING_ZIP_CODE_ERROR_MSG = 'Missing ZIP Code. ZIP Code must be 5 digits, ' \
      'or 9 digits in XXXXX-XXXX format. Specify \'00000\' for non-US addresses.'

    def perform(higher_level_review_id, retries = 0)
      @retries = retries
      pdf_constructor = AppealsApi::HigherLevelReviewPdfConstructor.new(higher_level_review_id)
      pdf_path = pdf_constructor.fill_pdf
      puts pdf_path
      # set status to processing until the central mail upload
      HigherLevelReview.update(higher_level_review_id, status: 'processing')
      # send to central mail
      upload_to_central_mail(higher_level_review_id, pdf_path)
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
        'document' => to_faraday_upload(pdf_path)
      }
      response = CentralMail::Service.new.upload(body)
      process_response(response, higher_level_review)
      log_submission(metadata)
    rescue AppealsApi::UploadError => e
      retry_errors(e, higher_level_review)
    end

    def retry_errors(e, uploaded_object)
      if e.code == 'DOC201' && @retries <= RETRIES
        self.class.new.perform_at(30.minutes.from_now, uploaded_object.id, @retries + 1)
      else
        uploaded_object.update(status: 'error', code: e.code, detail: e.detail)
      end
      log_error(e, uploaded_object)
    end

    def log_error(e, uploaded_object)
      Rails.logger.info('AppealsApi HigherLevelReview: Submission failure',
                        'source' => uploaded_object.auth_headers['consumer_name'],
                        'uuid' => uploaded_object.id,
                        'code' => e.code,
                        'detail' => e.detail)
    end

    def to_faraday_upload(file_path)
      Faraday::UploadIO.new(
        file_path,
        Mime[:pdf].to_s
      )
    end

    def process_response(response, higher_level_review)
      if response.success? || response.body.match?(NON_FAILING_ERROR_REGEX)
        higher_level_review.update(status: 'submitted')
      else
        map_downstream_error(response.status, response.body)
      end
    end

    def log_submission(metadata)
      Rails.logger.info('AppealsApi: Submission success',
                        'uuid' => metadata['uuid'],
                        'source' => metadata['source'],
                        'docType' => metadata['docType'],
                        'pageCount' => metadata['numberPages'])
    end

    def map_downstream_error(status, body)
      if status.between?(400, 499)
        detail = if body.match?(INVALID_ZIP_CODE_ERROR_REGEX)
                   INVALID_ZIP_CODE_ERROR_MSG
                 elsif body.match?(MISSING_ZIP_CODE_ERROR_REGEX)
                   MISSING_ZIP_CODE_ERROR_MSG
                 else
                   body
                 end
        raise AppealsApi::UploadError.new(code: 'DOC104', detail: "Downstream status: #{status} - #{detail}")
      # Defined values: 500
      elsif status.between?(500, 599)
        raise AppealsApi::UploadError.new(code: 'DOC201',
                                          detail: "Downstream status: #{status} - #{body}")
      end
    end
  end
end
