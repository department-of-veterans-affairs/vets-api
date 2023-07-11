# frozen_string_literal: true

require 'sidekiq'
require 'vba_documents/object_store'
require 'vba_documents/payload_manager'
require 'vba_documents/pdf_inspector'
require 'vba_documents/upload_error'
require 'central_mail/utilities'
require 'vba_documents/upload_validator'

module VBADocuments
  class UploadProcessor
    include Sidekiq::Worker
    include VBADocuments::UploadValidations

    STATSD_DUPLICATE_UUID_KEY = 'api.vba.document_upload.duplicate_uuid'
    STATSD_TIMING = 'api.vba.document_upload_perf_timing'

    # Ensure that multiple jobs for the same GUID aren't spawned,
    # to avoid race condition when parsing the multipart file
    sidekiq_options unique_for: 30.days

    def perform(guid, caller_data, retries = 0)
      return if cancelled?

      response = nil
      brt = Benchmark.realtime do
        # @retries variable used via the CentralMail::Utilities which is included via VBADocuments::UploadValidations
        @retries = retries
        @cause = caller_data.nil? ? { caller: 'unknown' } : caller_data['caller']
        response = nil
        VBADocuments::UploadSubmission.with_advisory_lock(guid) do
          @upload = VBADocuments::UploadSubmission.where(status: 'uploaded').find_by(guid:)
          if @upload
            tracking_hash = { 'job' => 'VBADocuments::UploadProcessor' }.merge(@upload.as_json)
            Rails.logger.info('VBADocuments: Start Processing.', tracking_hash)
            response = download_and_process
            tracking_hash = { 'job' => 'VBADocuments::UploadProcessor' }.merge(@upload.reload.as_json)
            Rails.logger.info('VBADocuments: Stop Processing.', tracking_hash)
          end
        end
      end
      StatsD.increment(STATSD_TIMING, tags: ["jid: #{jid}", "guid: #{@upload&.guid}", 'step: perform_complete',
                                             "time: #{brt.round(5)}}"])

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
      tempfile, timestamp = nil
      brt = Benchmark.realtime do
        tempfile, timestamp = VBADocuments::PayloadManager.download_raw_file(@upload.guid)
      end
      StatsD.increment(STATSD_TIMING, tags: ["jid: #{jid}", "guid: #{@upload.guid}", 'step: download_raw_file',
                                             "raw_file_size: #{tempfile.size}", "time: #{brt.round(5)}}"])

      response = nil
      begin
        parts, inspector = nil
        brt = Benchmark.realtime do
          @upload.update(metadata: @upload.metadata.merge(original_file_metadata(tempfile)))

          validate_payload_size(tempfile)

          parts = VBADocuments::MultipartParser.parse(tempfile.path)
          inspector = VBADocuments::PDFInspector.new(pdf: parts)
          @upload.update(uploaded_pdf: inspector.pdf_data)
        end
        StatsD.increment(STATSD_TIMING, tags: ["jid: #{jid}", "guid: #{@upload.guid}", 'step: parse_parts',
                                               "time: #{brt.round(5)}}"])

        metadata = nil
        brt = Benchmark.realtime do
          # Validations
          validate_parts(@upload, parts)
          validate_metadata(parts[META_PART_NAME], submission_version: @upload.metadata['version'].to_i)
          metadata = perfect_metadata(@upload, parts, timestamp)

          pdf_validator_options = VBADocuments::DocumentRequestValidator.pdf_validator_options
          validate_documents(parts, pdf_validator_options)
        end
        StatsD.increment(STATSD_TIMING, tags: ["jid: #{jid}", "guid: #{@upload.guid}", 'step: validate',
                                               "time: #{brt.round(5)}}"])

        brt = Benchmark.realtime do
          response = submit(metadata, parts)
        end
        StatsD.increment(STATSD_TIMING, tags: ["jid: #{jid}", "guid: #{@upload.guid}", 'step: cm_upload',
                                               "time: #{brt.round(5)}}"])

        brt = Benchmark.realtime do
          process_response(response)
          log_submission(@upload, metadata)
        end
        StatsD.increment(STATSD_TIMING, tags: ["jid: #{jid}", "guid: #{@upload.guid}", 'step: process_resp',
                                               "time: #{brt.round(5)}}"])
      rescue Common::Exceptions::GatewayTimeout => e
        handle_gateway_timeout(e)
      rescue VBADocuments::UploadError => e
        Rails.logger.warn("UploadError download_and_process for guid #{@upload.guid}.", e)
        retry_errors(e, @upload)
      ensure
        tempfile.close
        close_part_files(parts) if parts.present?
      end
      response
    end
    # rubocop:enable Metrics/MethodLength

    def original_file_metadata(tempfile)
      {
        'size' => tempfile.size,
        'base64_encoded' => VBADocuments::MultipartParser.base64_encoded?(tempfile.path),
        'sha256_checksum' => Digest::SHA256.file(tempfile).hexdigest,
        'md5_checksum' => Digest::MD5.file(tempfile).hexdigest
      }
    end

    def validate_payload_size(tempfile)
      unless tempfile.size.positive?
        raise VBADocuments::UploadError.new(code: 'DOC107', detail: VBADocuments::UploadError::DOC107)
      end
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
      if response.success?
        handle_successful_submission
      elsif response.status == 400 && response.body.match?(DUPLICATE_UUID_REGEX)
        StatsD.increment(STATSD_DUPLICATE_UUID_KEY)
        Rails.logger.warn("#{self.class.name}: Duplicate UUID submitted to Central Mail", 'uuid' => @upload.guid)
        # Treating these as a 'success' is intentional; we have confirmed that when we receive the 'duplicate UUID'
        # response from Central Mail, this indicates that there was an earlier submission that was successful
        handle_successful_submission
      elsif response.status == 429 && response.body =~ /UUID already in cache/
        @upload.track_uploaded_received(:uuid_already_in_cache_cause, @cause)
        @upload.track_concurrent_duplicate
      else
        map_error(response.status, response.body, VBADocuments::UploadError)
      end
    end

    def handle_successful_submission
      @upload.update(status: 'received')
      @upload.track_uploaded_received(:cause, @cause)
    end
  end
end
