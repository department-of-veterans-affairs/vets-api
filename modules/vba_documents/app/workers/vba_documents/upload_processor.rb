# frozen_string_literal: true

require_dependency 'vba_documents/multipart_parser'
require_dependency 'vba_documents/payload_manager'
require_dependency 'vba_documents/pdf_inspector'

require 'central_mail/utilities'
require 'central_mail/service'
require 'pdf_info'
require 'sidekiq'
require 'vba_documents/object_store'
require 'vba_documents/upload_error'

module VBADocuments
  class UploadProcessor
    include Sidekiq::Worker
    include CentralMail::Utilities

    def perform(guid, retries = 0)
      @retries = retries
      @upload = VBADocuments::UploadSubmission.where(status: 'uploaded').find_by(guid: guid)
      if @upload
        Rails.logger.info("VBADocuments: Start Processing: #{@upload.inspect}")
        download_and_process
        Rails.logger.info("VBADocuments: Stop Processing: #{@upload.inspect}")
      end
    end

    private

    def download_and_process
      tempfile, timestamp = VBADocuments::PayloadManager.download_raw_file(@upload.guid)

      begin
        parts = VBADocuments::MultipartParser.parse(tempfile.path)
        inspector = VBADocuments::PDFInspector.new(pdf: parts)
        validate_parts(parts)
        validate_metadata(parts[META_PART_NAME])
        update_pdf_metadata(inspector)
        metadata = perfect_metadata(parts, timestamp)
        response = submit(metadata, parts)
        process_response(response)
        log_submission(@upload, metadata)
      rescue Common::Exceptions::GatewayTimeout, Faraday::TimeoutError
        VBADocuments::UploadSubmission.refresh_statuses!([@upload])
      rescue VBADocuments::UploadError => e
        retry_errors(e, @upload)
      ensure
        tempfile.close
        close_part_files(parts) if parts.present?
      end
    end

    def update_pdf_metadata(inspector)
      @upload.update(uploaded_pdf: inspector.pdf_data)
    end

    def close_part_files(parts)
      parts[DOC_PART_NAME]&.close if parts[DOC_PART_NAME].respond_to? :close
      attachment_names = parts.keys.select { |k| k.match(/attachment\d+/) }
      attachment_names.each do |att|
        parts[att]&.close if parts[att].respond_to? :close
      end
    end

    def submit(metadata, parts)
      parts[DOC_PART_NAME].rewind
      body = {
        META_PART_NAME => metadata.to_json,
        SUBMIT_DOC_PART_NAME => to_faraday_upload(parts[DOC_PART_NAME], 'document.pdf')
      }
      attachment_names = parts.keys.select { |k| k.match(/attachment\d+/) }
      attachment_names.each_with_index do |att, i|
        parts[att].rewind
        body["attachment#{i + 1}"] = to_faraday_upload(parts[att], "attachment#{i + 1}.pdf")
      end
      CentralMail::Service.new.upload(body)
    end

    def process_response(response)
      if response.success? || response.body.match?(NON_FAILING_ERROR_REGEX)
        @upload.update(status: 'received')
      else
        map_error(response.status, response.body, VBADocuments::UploadError)
      end
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
      # TODO: validate type and sequential naming of attachment parts
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
    rescue JSON::ParserError
      raise VBADocuments::UploadError.new(code: 'DOC102', detail: 'Invalid JSON object')
    end

    def perfect_metadata(parts, timestamp)
      metadata = JSON.parse(parts['metadata'])
      metadata['source'] = "#{@upload.consumer_name} via VA API"
      metadata['receiveDt'] = timestamp.in_time_zone('US/Central').strftime('%Y-%m-%d %H:%M:%S')
      metadata['uuid'] = @upload.guid
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
