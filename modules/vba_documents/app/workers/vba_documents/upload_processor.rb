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

    def perform(guid, retries = 0, **caller_data)
      @retries = retries
      @cause = caller_data[:caller].nil? ? :unknown : caller_data[:caller]
      Rails.logger.info("Hi Guys processing #{guid}!!!!!!!!!!!!! my cause is #{@cause}")
      Rails.logger.info("Hi Guys processing a guid!!!!!!!!!!!!! my caller_data is #{caller_data}")
      # @retries variable used via the CentralMail::Utilities which is included via
      # VBADocuments::UploadValidations
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

    private

    # rubocop:disable Metrics/MethodLength
    def download_and_process
      tempfile, timestamp = VBADocuments::PayloadManager.download_raw_file(@upload.guid)
      response = nil
      begin
        update_size(@upload, tempfile.size)
        parts = VBADocuments::MultipartParser.parse(tempfile.path)
        inspector = VBADocuments::PDFInspector.new(pdf: parts)
        validate_parts(parts)
        validate_metadata(parts[META_PART_NAME])
        update_pdf_metadata(@upload, inspector)
        metadata = perfect_metadata(@upload, parts, timestamp)
        response = submit(metadata, parts)
        process_response(response)
        log_submission(@upload, metadata)
      rescue Common::Exceptions::GatewayTimeout, Faraday::TimeoutError => e
        Rails.logger.warn("Exception in download_and_process for guid #{@upload.guid}.", e)
        VBADocuments::UploadSubmission.refresh_statuses!([@upload])
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
      Rails.logger.info("Hi Guys in process_response!!!!!!!!!!!! my cause is #{@cause}")
      # record submission attempt, record time and success status to an array\
      # record response.body
      if response.success? || response.body.match?(NON_FAILING_ERROR_REGEX)
        @upload.update(status: 'received')
        record_attempts(:received)
      elsif response.status == 429 && response.body =~ /UUID already in cache/
        record_attempts(:uploaded)
        process_concurrent_duplicate
      else
        map_error(response.status, response.body, VBADocuments::UploadError)
      end
    end

    def record_attempts(status)
      Rails.logger.info("Hi Guys in record_attempts!!!!!!!!!!!! my cause is #{@cause}")
      if (status.eql? :uploaded)
        Rails.logger.info("Hi Guys in record_attempts uploaded!!!!!!!!!!!! my cause is #{@cause}")
        @upload.metadata['status']['uploaded']['attempts'] ||= {}
        @upload.metadata['status']['uploaded']['attempts'][@cause] ||= []
        @upload.metadata['status']['uploaded']['attempts'][@cause] << Time.now.to_i
      elsif(status.eql? :received)
        Rails.logger.info("Hi Guys in record_attempts received!!!!!!!!!!!! my cause is #{@cause}")
        @upload.metadata['status']['uploaded']['cause'] ||= []
        @upload.metadata['status']['uploaded']['cause'] << @cause #should *never* have an array greater than 1 in length
      end
      saved = @upload.save
    rescue => ex
      Rails.logger.info("Hi Guys in record_attempts saving!!!!!!!!!!!! my save is #{saved}")
      Rails.logger.info("Hi Guys in record_attempts exception!!!!!!!!!!!! my save is #{ex}", ex)
    end

=begin
{"size"=>279144,
"status"=>{
    "vbms"=>{"start"=>1621951451},
    "pending"=>{"end"=>1621875664, "start"=>1621875659},
    "success"=>{"end"=>1621951451, "start"=>1621933462,},
    "received"=>{"end"=>1621897451, "start"=>1621897441, cause 'manual, v0, upload_scanner, unsuccessful' },
    "uploaded"=>{"end"=>1621897441, "start"=>1621875664, attempts: {v0 => [t1,t2,t3], 'manual' => [t1,t2], upload_scanner => [t1], unsuccessful =>[] },
                 "processing"=>{"end"=>1621933462, "start"=>1621897451}},
    "last_slack_notification"=>1621890000,
    "uuid_already_in_cache_count"=>2
}
=end


    def process_concurrent_duplicate

      # This should never occur now that we are using with_advisory_lock in perform, but if it does we will record it
      # and otherwise leave this model alone as another instance of this job is currently also processing this guid
      @upload.metadata['uuid_already_in_cache_count'] ||= 0
      @upload.metadata['uuid_already_in_cache_count'] += 1
      @upload.save!
    end
  end
end
