# frozen_string_literal: true

require 'central_mail/utilities'
require 'central_mail/service'
require 'pdf_utilities/pdf_validator'
require 'vba_documents/document_request_validator'

# rubocop:disable Metrics/ModuleLength
module VBADocuments
  module UploadValidations
    include CentralMail::Utilities
    include PDFUtilities

    VALID_VETERAN_NAME_REGEX = %r{\A[a-zA-Z\-/\s]{1,50}\z}

    def validate_parts(model, parts)
      unless parts.key?(META_PART_NAME)
        raise VBADocuments::UploadError.new(code: 'DOC102',
                                            detail: 'No metadata part present')
      end
      unless parts[META_PART_NAME].is_a?(String)
        raise VBADocuments::UploadError.new(code: 'DOC102',
                                            detail: 'Incorrect content-type for metadata part')
      end
      unless parts.key?(DOC_PART_NAME)
        raise VBADocuments::UploadError.new(code: 'DOC103',
                                            detail: 'Submission did not include a document.')
      end
      if parts[DOC_PART_NAME].is_a?(String)
        raise VBADocuments::UploadError.new(code: 'DOC103',
                                            detail: 'Incorrect content-type for document part')
      end
      regex = /^#{META_PART_NAME}|#{DOC_PART_NAME}|attachment\d+$/
      invalid_parts = parts.keys.reject { |key| regex.match?(key) }
      log_invalid_parts(model, invalid_parts) if invalid_parts.any?
    end

    def validate_metadata(metadata_input, submission_version:)
      metadata = JSON.parse(metadata_input)
      raise VBADocuments::UploadError.new(code: 'DOC102', detail: 'Invalid JSON object') unless metadata.is_a?(Hash)

      missing_keys = REQUIRED_KEYS - metadata.keys
      if missing_keys.present?
        raise VBADocuments::UploadError.new(code: 'DOC102', detail: "Missing required keys: #{missing_keys.join(',')}")
      end

      rejected = REQUIRED_KEYS.reject { |k| metadata[k].is_a? String }
      if rejected.present?
        raise VBADocuments::UploadError.new(code: 'DOC102', detail: "Non-string values for keys: #{rejected.join(',')}")
      end
      if (FILE_NUMBER_REGEX =~ metadata['fileNumber']).nil?
        raise VBADocuments::UploadError.new(code: 'DOC102', detail: 'Non-numeric or invalid-length fileNumber')
      end

      validate_veteran_name(metadata['veteranFirstName'].strip, metadata['veteranLastName'].strip)
      validate_line_of_business(metadata['businessLine'], submission_version)
    rescue JSON::ParserError
      raise VBADocuments::UploadError.new(code: 'DOC102', detail: 'Invalid JSON object')
    end

    def validate_documents(parts, pdf_validator_options = VBADocuments::DocumentRequestValidator.pdf_validator_options)
      # Validate 'content' document
      validate_document(parts[DOC_PART_NAME], DOC_PART_NAME, pdf_validator_options)

      # Validate attachments
      attachment_names = parts.keys.select { |key| key.match(/attachment\d+/) }
      attachment_names.each do |attachment_name|
        validate_document(parts[attachment_name], attachment_name, pdf_validator_options)
      end
    end

    def perfect_metadata(model, parts, timestamp)
      metadata = JSON.parse(parts['metadata'])
      metadata['source'] = "#{model.consumer_name} via VA API"
      metadata['receiveDt'] = timestamp.in_time_zone('US/Central').strftime('%Y-%m-%d %H:%M:%S')
      metadata['uuid'] = model.guid
      metadata['hashV'] = model.uploaded_pdf.dig('content', 'sha256_checksum')
      metadata['numberPages'] = model.uploaded_pdf.dig('content', 'page_count')
      attachment_names = parts.keys.select { |k| k.match(/attachment\d+/) }
      metadata['numberAttachments'] = attachment_names.size
      attachment_names.each_index do |i|
        metadata["ahash#{i + 1}"] = model.uploaded_pdf.dig('content', 'attachments', i, 'sha256_checksum')
        metadata["numberPages#{i + 1}"] = model.uploaded_pdf.dig('content', 'attachments', i, 'page_count')
      end
      metadata['businessLine'] = VALID_LOB[metadata['businessLine'].to_s.upcase] if metadata.key? 'businessLine'
      metadata['businessLine'] = AppealsApi::LineOfBusiness.new(model).value if model.appeals_consumer?
      metadata
    end

    private

    def validate_veteran_name(first, last)
      [first, last].each do |name|
        msg = 'Invalid Veteran name (e.g. empty, invalid characters, or too long). '
        msg += "Names must match the regular expression #{VALID_VETERAN_NAME_REGEX.inspect}"
        raise VBADocuments::UploadError.new(code: 'DOC102', detail: msg) unless name =~ VALID_VETERAN_NAME_REGEX
      end
    end

    def validate_line_of_business(lob, submission_version)
      return if lob.to_s.empty? && !(submission_version && submission_version >= 2)

      if lob.to_s.blank? && submission_version >= 2
        msg = "The businessLine metadata field is missing or empty. Valid values are: #{VALID_LOB.keys.join(',')}"
        raise VBADocuments::UploadError.new(code: 'DOC102', detail: msg)
      end

      unless VALID_LOB.keys.include?(lob.to_s.upcase)
        msg = "Invalid businessLine provided - {#{lob}}, valid values are: #{VALID_LOB.keys.join(',')}"
        raise VBADocuments::UploadError.new(code: 'DOC102', detail: msg)
      end
    end

    def validate_document(file_path, part_name, pdf_validator_options = {})
      result = PDFValidator::Validator.new(file_path, pdf_validator_options).validate

      unless result.valid_pdf?
        errors = result.errors

        if errors.grep(/#{PDFValidator::FILE_SIZE_LIMIT_EXCEEDED_MSG}/).any?
          code = 'DOC106'
          detail = CentralMail::UploadError.default_message(code, pdf_validator_options)
          raise VBADocuments::UploadError.new(code:, detail:, pdf_validator_options:)
        end

        if errors.grep(/#{PDFValidator::USER_PASSWORD_MSG}|#{PDFValidator::INVALID_PDF_MSG}/).any?
          raise VBADocuments::UploadError.new(code: 'DOC103',
                                              detail: "Invalid PDF content, part #{part_name}",
                                              pdf_validator_options:)
        end

        if errors.grep(/#{PDFValidator::PAGE_SIZE_LIMIT_EXCEEDED_MSG}/).any?
          code = 'DOC108'
          detail = CentralMail::UploadError.default_message(code, pdf_validator_options)
          raise VBADocuments::UploadError.new(code:, detail:, pdf_validator_options:)
        end
      end
    end

    def log_invalid_parts(model, invalid_parts)
      message = "VBADocuments Invalid Part Uploaded\t"\
                "GUID: #{model.guid}\t"\
                "Uploaded Time: #{model.created_at}\t"\
                "Consumer Name: #{model.consumer_name}\t"\
                "Consumer Id: #{model.consumer_id}\t"\
                "Invalid parts: #{invalid_parts}\t"
      Rails.logger.warn(message)
      model.metadata['invalid_parts'] = invalid_parts
    end
  end
end
# rubocop:enable Metrics/ModuleLength
