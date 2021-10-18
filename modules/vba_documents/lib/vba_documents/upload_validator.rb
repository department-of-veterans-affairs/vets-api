# frozen_string_literal: true

require_dependency 'vba_documents/pdf_inspector'

require 'central_mail/utilities'
require 'central_mail/service'
require 'pdf_info'

# rubocop:disable Metrics/ModuleLength
module VBADocuments
  module UploadValidations
    include CentralMail::Utilities

    VALID_NAME = %r{^[a-zA-Z\-\/\s]{1,50}$}.freeze

    def update_pdf_metadata(model, inspector)
      model.update(uploaded_pdf: inspector.pdf_data)
    end

    def update_size(model, size)
      model.update(metadata: model.metadata.merge({ 'size' => size }))
    end

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

      validate_names(metadata['veteranFirstName'].strip, metadata['veteranLastName'].strip)
      validate_line_of_business(metadata['businessLine'], submission_version)
    rescue JSON::ParserError
      raise VBADocuments::UploadError.new(code: 'DOC102', detail: 'Invalid JSON object')
    end

    def validate_names(first, last)
      [first, last].each do |name|
        msg = 'Invalid Veteran name (e.g. empty, invalid characters, or too long). '
        msg += "Names must match the regular expression #{VALID_NAME.inspect}"
        raise VBADocuments::UploadError.new(code: 'DOC102', detail: msg) unless name =~ VALID_NAME
      end
    end

    def validate_line_of_business(lob, submission_version)
      return if lob.to_s.empty? && !(submission_version && submission_version >= 2)

      if lob.to_s.blank? && submission_version >= 2
        msg = "The businessLine metadata field is missing or empty. Valid values are: #{VALID_LOB_MSG.keys.join(',')}"
        raise VBADocuments::UploadError.new(code: 'DOC102', detail: msg)
      end

      unless VALID_LOB.keys.include?(lob.to_s.upcase)
        msg = "Invalid businessLine provided - {#{lob}}, valid values are: #{VALID_LOB_MSG.keys.join(',')}"
        raise VBADocuments::UploadError.new(code: 'DOC102', detail: msg)
      end
    end

    # rubocop:disable Metrics/MethodLength
    def perfect_metadata(model, parts, timestamp)
      metadata = JSON.parse(parts['metadata'])
      metadata['source'] = "#{model.consumer_name} via VA API"
      metadata['receiveDt'] = timestamp.in_time_zone('US/Central').strftime('%Y-%m-%d %H:%M:%S')
      metadata['uuid'] = model.guid
      check_size(parts[DOC_PART_NAME])
      doc_info = get_hash_and_pages(parts[DOC_PART_NAME], DOC_PART_NAME)
      validate_page_size(doc_info)
      metadata['hashV'] = doc_info[:hash]
      metadata['numberPages'] = doc_info[:pages]
      attachment_names = parts.keys.select { |k| k.match(/attachment\d+/) }
      metadata['numberAttachments'] = attachment_names.size
      attachment_names.each_with_index do |att, i|
        att_info = get_hash_and_pages(parts[att], att)
        validate_page_size(att_info)
        check_attachment_size(parts[att])
        metadata["ahash#{i + 1}"] = att_info[:hash]
        metadata["numberPages#{i + 1}"] = att_info[:pages]
      end
      metadata['businessLine'] = VALID_LOB[metadata['businessLine'].to_s.upcase] if metadata.key? 'businessLine'
      metadata['businessLine'] = AppealsApi::LineOfBusiness.new(model).value if model.appeals_consumer?
      metadata
    end
    # rubocop:enable Metrics/MethodLength

    def check_attachment_size(att_parts)
      Thread.current[:checking_attachment] = true # used during unit test only, see upload_processor_spec.rb
      check_size(att_parts)
      Thread.current[:checking_attachment] = false
    end

    def validate_page_size(doc_info)
      if doc_info[:size][:height] >= 21 || doc_info[:size][:width] >= 21
        raise VBADocuments::UploadError.new(code: 'DOC108',
                                            detail: VBADocuments::UploadError::DOC108)
      end
    end

    def check_size(file_path)
      if File.size(file_path) > MAX_PART_SIZE
        raise VBADocuments::UploadError.new(code: 'DOC106',
                                            detail: 'Maximum document size exceeded. Limit is 100MB per document')
      end
    end

    def get_hash_and_pages(file_path, part)
      metadata = PdfInfo::Metadata.read(file_path)
      {
        hash: Digest::SHA256.file(file_path).hexdigest,
        pages: metadata.pages,
        size: metadata.page_size_inches
      }
    rescue PdfInfo::MetadataReadError
      raise VBADocuments::UploadError.new(code: 'DOC103',
                                          detail: "Invalid PDF content, part #{part}")
    end

    private

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
