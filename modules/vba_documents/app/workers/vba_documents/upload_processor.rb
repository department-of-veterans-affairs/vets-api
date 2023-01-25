# frozen_string_literal: true

require_dependency 'vba_documents/upload_validator'
require_dependency 'vba_documents/payload_manager'
require_dependency 'vba_documents/multipart_parser'

require 'sidekiq'
require 'vba_documents/object_store'
require 'vba_documents/upload_error'
require 'central_mail/utilities'

module VBADocuments
  class UploadProcessor
    include Sidekiq::Worker
    include VBADocuments::UploadValidations

    # Ensure that multiple jobs for the same GUID aren't spawned,
    # to avoid race condition when parsing the multipart file
    sidekiq_options unique_for: 30.days

    def perform(guid, caller_data, retries = 0)
      return if cancelled?

      # @retries variable used via the CentralMail::Utilities which is included via VBADocuments::UploadValidations
      @retries = retries
      @cause = caller_data.nil? ? { caller: 'unknown' } : caller_data['caller']
      response = nil
      VBADocuments::UploadSubmission.with_advisory_lock(guid) do
        @upload = VBADocuments::UploadSubmission.where(status: 'uploaded').find_by(guid: guid)
        if @upload
          tracking_hash = { 'job' => 'VBADocuments::UploadProcessor' }.merge(@upload.as_json)
          Rails.logger.info('VBADocuments: Start Processing.', tracking_hash)
          response = download_and_process
          tracking_hash = { 'job' => 'VBADocuments::UploadProcessor' }.merge(@upload.reload.as_json)
          Rails.logger.info('VBADocuments: Stop Processing.', tracking_hash)
        end
      end
      response&.success? ? true : false
    end

    def cancelled?
      Sidekiq.redis do |c|
        if c.respond_to? :exists?
          c.exists?("cancelled-#{jid}")
        else
          c.exists("cancelled-#{jid}")
        end
      end
    end

    def self.cancel!(jid)
      Sidekiq.redis { |c| c.setex("cancelled-#{jid}", 86_400, 1) }
    end

    private

    # rubocop:disable Metrics/MethodLength
    def download_and_process
      tempfile, timestamp = VBADocuments::PayloadManager.download_raw_file(@upload.guid)
      response = nil
      begin
        @upload.update(metadata: @upload.metadata.merge(original_file_metadata(tempfile)))

        parts = VBADocuments::MultipartParser.parse(tempfile.path)
        inspector = VBADocuments::PDFInspector.new(pdf: parts['contents'])
        @upload.update(uploaded_pdf: inspector.pdf_data)

        # Validations
        validate_parts(@upload, parts['contents'])
        validate_metadata(parts['contents'][META_PART_NAME], submission_version: @upload.metadata['version'].to_i)
        validate_documents(parts['contents'])

        metadata = perfect_metadata(@upload, parts['contents'], timestamp)
        response = submit(metadata, parts['contents'])

        process_response(response)
        log_submission(@upload, metadata)
      rescue Common::Exceptions::GatewayTimeout => e
        handle_gateway_timeout(e)
      rescue VBADocuments::UploadError => e
        Rails.logger.warn("UploadError download_and_process for guid #{@upload.guid}.", e)
        retry_errors(e, @upload)
      ensure
        tempfile.close
        close_part_files(parts['contents']) if parts.present? && parts['contents'].present?
      end
      response
    end
    # rubocop:enable Metrics/MethodLength

    def original_file_metadata(tempfile)
      {
        'size' => tempfile.size,
        'base64_encoded' => VBADocuments::MultipartParser.base64_encoded?(tempfile.path),
        'original_checksum' => Digest::SHA256.file(tempfile).hexdigest
      }
    end

    def handle_gateway_timeout(error)
      message = "Exception in download_and_process for guid #{@upload.guid}, size: #{@upload.metadata['size']} bytes."
      Rails.logger.warn(message, error)

      @upload.track_upload_timeout_error

      if @upload.hit_upload_timeout_limit?
        @upload.update(status: 'error', code: 'DOC104', detail: 'Request timed out uploading to upstream system')
      end

      VBADocuments::UploadSubmission.refresh_statuses!([@upload])
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
      # record submission attempt, record time and success status to an array
      if response.success? || response.body.match?(NON_FAILING_ERROR_REGEX) # TODO: GovCIO needs to return this...
        @upload.update(status: 'received')
        @upload.track_uploaded_received(:cause, @cause)
      elsif response.status == 429 && response.body =~ /UUID already in cache/
        @upload.track_uploaded_received(:uuid_already_in_cache_cause, @cause)
        @upload.track_concurrent_duplicate
      else
        map_error(response.status, response.body, VBADocuments::UploadError)
      end
    end
  end
end
