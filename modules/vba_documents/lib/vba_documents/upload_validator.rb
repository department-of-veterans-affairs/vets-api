# frozen_string_literal: true

require_dependency 'vba_documents/pdf_inspector'

require 'central_mail/utilities'
require 'central_mail/service'
require 'pdf_info'

# rubocop:disable Metrics/ModuleLength
module VBADocuments
  module UploadValidations
    include CentralMail::Utilities

    def update_pdf_metadata(model, inspector)
      model.update(uploaded_pdf: inspector.pdf_data)
    end

    def update_size(model, size)
      model.update(metadata: model.metadata.merge({ 'size' => size }))
    end

    def validate_parts(parts)
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
    end

    def validate_metadata(metadata_input)
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

      # this validate_not_empty check should be after the Non-string value check so we do not catch nulls
      validate_not_empty(veteranFirstName: metadata['veteranFirstName'], veteranLastName: metadata['veteranLastName'])
      validate_line_of_business(metadata['businessLine'])
    rescue JSON::ParserError
      raise VBADocuments::UploadError.new(code: 'DOC102', detail: 'Invalid JSON object')
    end

    def validate_not_empty(hash)
      unless hash.values.map(&:to_s).select(&:empty?).empty?
        msg = "Empty value given - The following values must be non-empty: #{hash.keys.join(',')}"
        raise VBADocuments::UploadError.new(code: 'DOC102', detail: msg)
      end
    end

    def validate_line_of_business(lob)
      return if lob.to_s.empty?

      unless VALID_LOB.keys.include?(lob)
        msg = "Invalid businessLine provided - {#{lob}}, valid values are: #{VALID_LOB.keys.join(',')}"
        raise VBADocuments::UploadError.new(code: 'DOC102', detail: msg)
      end
    end

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
      metadata['businessLine'] = VALID_LOB[metadata['businessLine']].to_s if metadata.key? 'businessLine'
      metadata
    end

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
  end
end
# rubocop:enable Metrics/ModuleLength
