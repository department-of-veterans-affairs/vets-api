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
    include Sidekiq::Job
    include VBADocuments::UploadValidations

    STATSD_DUPLICATE_UUID_KEY = 'api.vba.document_upload.duplicate_uuid'

    # Ensure that multiple jobs for the same GUID aren't spawned,
    # to avoid race condition when parsing the multipart file
    sidekiq_options unique_for: 30.days

    def perform(guid, caller_data, retries = 0)
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

      response&.success? || false
    end

    private

    # rubocop:disable Metrics/MethodLength
    def download_and_process
      tempfile, timestamp = VBADocuments::PayloadManager.download_raw_file(@upload.guid)
      response = nil

      begin
        @upload.update(metadata: @upload.metadata.merge(original_file_metadata(tempfile)))
        validate_payload_size(tempfile)

        # parse out multipart consumer supplied file into individual parts
        parts = VBADocuments::MultipartParser.parse(tempfile.path)

        # Attempt to use consumer supplied file number field to look up the claiments ICN
        # asap for tracking consumer's impacted
        icn = find_icn(parts)
        @upload.update(metadata: @upload.metadata.merge({ 'icn' => icn })) if icn.present?

        inspector = VBADocuments::PDFInspector.new(pdf: parts)
        @upload.update(uploaded_pdf: inspector.pdf_data)

        # Validations
        validate_parts(@upload, parts)
        validate_metadata(parts[META_PART_NAME], @upload.consumer_id, @upload.guid,
                          submission_version: @upload.metadata['version'].to_i)
        metadata = perfect_metadata(@upload, parts, timestamp)

        pdf_validator_options = VBADocuments::DocumentRequestValidator.pdf_validator_options
        validate_documents(parts, pdf_validator_options)

        response = submit(metadata, parts)

        process_response(response)
        log_submission(@upload, metadata)
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

    def find_icn(parts)
      file_number = read_original_metadata_file_number(parts)

      return if file_number.blank?

      bgss = BGS::Services.new(external_uid: file_number, external_key: file_number)

      # File Number is ssn, file number, or participant id.  Call BGS to get the veterans birthdate
      # rubocop:disable Rails/DynamicFindBy
      bgs_vet = bgss.people.find_by_ssn(file_number) ||
                bgss.people.find_by_file_number(file_number) ||
                bgss.people.find_person_by_ptcpnt_id(file_number)
      # rubocop:enable Rails/DynamicFindBy

      return nil if bgs_vet.blank? || bgs_vet[:brthdy_dt].blank? || bgs_vet[:ssn_nbr].blank?

      # Go after ICN in MPI
      mpi = MPI::Service.new
      r = mpi.find_profile_by_attributes(first_name: bgs_vet[:first_nm].to_s,
                                         last_name: bgs_vet[:last_nm].to_s,
                                         ssn: bgs_vet[:ssn_nbr].to_s,
                                         birth_date: bgs_vet[:brthdy_dt].strftime('%Y-%m-%d'))
      return nil if r.blank? || r.profile.blank?

      r.profile.icn

    # at this point ICN is not required when submitting to EMMS, so have wide
    # exception handling, log and move on, any errors trying to get ICN should not stop us from submitting
    rescue => e
      Rails.logger.error("Benefits Intake UploadProcessor find_icn failed. Guid: #{@upload.guid}, " \
                         "Exception: #{e.message}")
      nil
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
