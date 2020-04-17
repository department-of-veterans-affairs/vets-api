# frozen_string_literal: true

require 'sidekiq'
require_dependency 'vba_documents/multipart_parser'
require_dependency 'vba_documents/payload_manager'
require 'vba_documents/object_store'
require 'vba_documents/upload_error'

module VBADocuments
  class UploadProcessor
    include Sidekiq::Worker

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
        validate_parts(parts)
        validate_metadata(parts[META_PART_NAME])
        metadata = perfect_metadata(parts, timestamp)
        response = submit(metadata, parts)
        process_response(response)
        log_submission(metadata)
      rescue VBADocuments::UploadError => e
        retry_errors(e)
      ensure
        tempfile.close
        close_part_files(parts) if parts.present?
      end
    end

    def retry_errors(e)
      if e.code == 'DOC201' && @retries <= RETRIES
        UploadProcessor.perform_in(30.minutes, @upload.guid, @retries + 1)
      else
        @upload.update(status: 'error', code: e.code, detail: e.detail)
      end
      log_error(e)
    end

    def log_error(e)
      Rails.logger.info('VBADocuments: Submission failure',
                        'consumer_id' => @upload.consumer_id,
                        'consumer_username' => @upload.consumer_name,
                        'source' => @upload.consumer_name,
                        'uuid' => @upload.guid,
                        'code' => e.code,
                        'detail' => e.detail)
    end

    def log_submission(metadata)
      page_total = metadata.select { |k, _| k.to_s.start_with?('numberPages') }.reduce(0) { |sum, (_, v)| sum + v }
      pdf_total = metadata.select { |k, _| k.to_s.start_with?('numberPages') }.count
      Rails.logger.info('VBADocuments: Submission success',
                        'uuid' => metadata['uuid'],
                        'source' => @upload.consumer_name,
                        'consumer_id' => @upload.consumer_id,
                        'consumer_username' => @upload.consumer_name,
                        'docType' => metadata['docType'],
                        'pageCount' => page_total,
                        'pdfCount' => pdf_total)
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

    def to_faraday_upload(file_io, filename)
      Faraday::UploadIO.new(
        file_io,
        Mime[:pdf].to_s,
        filename
      )
    end

    def process_response(response)
      if response.success? || response.body.match?(NON_FAILING_ERROR_REGEX)
        @upload.update(status: 'received')
      else
        map_downstream_error(response.status, response.body)
      end
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
        raise VBADocuments::UploadError.new(code: 'DOC104', detail: "Downstream status: #{status} - #{detail}")
      # Defined values: 500
      elsif status.between?(500, 599)
        raise VBADocuments::UploadError.new(code: 'DOC201',
                                            detail: "Downstream status: #{status} - #{body}")
      end
    end

    def validate_parts(parts)
      unless parts.key?(META_PART_NAME)
        raise VBADocuments::UploadError.new(code: 'DOC102',
                                            detail: 'No metadata part present')
      end
      unless parts[META_PART_NAME].is_a?(String)
        raise VBADocuments::UploadError.new(code: 'DOC102',
                                            detail: 'Incorrect content-type for metdata part')
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
      missing_keys = REQUIRED_KEYS - metadata.keys
      if missing_keys.present?
        raise VBADocuments::UploadError.new(code: 'DOC102',
                                            detail: "Missing required keys: #{missing_keys.join(',')}")
      end
      non_string_vals = REQUIRED_KEYS.reject { |k| metadata[k].is_a? String }
      if non_string_vals.present?
        raise VBADocuments::UploadError.new(code: 'DOC102',
                                            detail: "Non-string values for keys: #{non_string_vals.join(',')}")
      end
      if (FILE_NUMBER_REGEX =~ metadata['fileNumber']).nil?
        raise VBADocuments::UploadError.new(code: 'DOC102',
                                            detail: 'Non-numeric or invalid-length fileNumber')
      end
    rescue JSON::ParserError
      raise VBADocuments::UploadError.new(code: 'DOC102',
                                          detail: 'Invalid JSON content')
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
        check_size(parts[att])
        metadata["ahash#{i + 1}"] = att_info[:hash]
        metadata["numberPages#{i + 1}"] = att_info[:pages]
      end
      metadata
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
