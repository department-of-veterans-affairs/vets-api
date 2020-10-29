# frozen_string_literal: true

module CentralMail
  module Utilities
    RETRIES = 3
    META_PART_NAME = 'metadata'
    DOC_PART_NAME = 'content'
    SUBMIT_DOC_PART_NAME = 'document'
    REQUIRED_KEYS = %w[veteranFirstName veteranLastName fileNumber zipCode].freeze
    FILE_NUMBER_REGEX = /^\d{8,9}$/.freeze
    MAX_PART_SIZE = 100_000_000 # 100MB
    INVALID_ZIP_CODE_ERROR_REGEX = /Invalid zipCode/.freeze
    MISSING_ZIP_CODE_ERROR_REGEX = /Missing zipCode/.freeze
    NON_FAILING_ERROR_REGEX = /Document already uploaded with uuid/.freeze
    INVALID_ZIP_CODE_ERROR_MSG = 'Invalid ZIP Code. ZIP Code must be 5 digits, ' \
      'or 9 digits in XXXXX-XXXX format. Specify \'00000\' for non-US addresses.'
    MISSING_ZIP_CODE_ERROR_MSG = 'Missing ZIP Code. ZIP Code must be 5 digits, ' \
      'or 9 digits in XXXXX-XXXX format. Specify \'00000\' for non-US addresses.'

    def log_submission(uploaded_object, metadata)
      number_pages = metadata.select { |k, _| k.to_s.start_with?('numberPages') }
      page_total = number_pages.reduce(0) { |sum, (_, v)| sum + v }
      pdf_total = number_pages.count

      title = uploaded_object.class.to_s.split('::').first
      Rails.logger.info("#{title}: Submission success",
                        'uuid' => metadata['uuid'],
                        'source' => metadata['source'],
                        'docType' => metadata['docType'],
                        'consumer_id' => uploaded_object.consumer_id,
                        'consumer_username' => uploaded_object.consumer_name,
                        'pageCount' => page_total,
                        'pdfCount' => pdf_total)
    end

    def retry_errors(e, uploaded_object)
      if e.code == 'DOC201' && @retries <= RETRIES
        self.class.perform_at(30.minutes.from_now, uploaded_object.id, @retries + 1)
      else
        uploaded_object.update(status: 'error', code: e.code, detail: e.detail)
      end
      log_error(e, uploaded_object)
    end

    def log_error(e, uploaded_object)
      Rails.logger.info("#{uploaded_object.class.to_s.gsub('::', ' ')}: Submission failure",
                        'source' => uploaded_object.consumer_name,
                        'consumer_id' => uploaded_object.consumer_id,
                        'consumer_username' => uploaded_object.consumer_name,
                        'uuid' => uploaded_object.id,
                        'code' => e.code,
                        'detail' => e.detail)
    end

    def to_faraday_upload(file_path, filename)
      Faraday::UploadIO.new(
        file_path,
        Mime[:pdf].to_s,
        filename
      )
    end

    def map_error(status, body, error_class)
      if status.between?(400, 499)
        detail = if body.match?(INVALID_ZIP_CODE_ERROR_REGEX)
                   INVALID_ZIP_CODE_ERROR_MSG
                 elsif body.match?(MISSING_ZIP_CODE_ERROR_REGEX)
                   MISSING_ZIP_CODE_ERROR_MSG
                 else
                   body
                 end
        raise error_class.new(code: 'DOC104', detail: "Upstream status: #{status} - #{detail}")
      # Defined values: 500
      elsif status.between?(500, 599)
        raise error_class.new(code: 'DOC201',
                              detail: "Downstream status: #{status} - #{body}")
      end
    end
  end
end
