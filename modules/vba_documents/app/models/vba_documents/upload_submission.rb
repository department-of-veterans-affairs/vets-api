# frozen_string_literal: true

module VBADocuments
  class UploadSubmission < ActiveRecord::Base
    include SetGuid
    include SentryLogging

    IN_FLIGHT_STATUSES = %w[received processing].freeze

    # TODO: Persist this? Otherwise it regenerates with new expiry
    # every time object is serialized
    def get_location
      rewrite_url(signed_url(guid))
    end

    def refresh_status!
      if status_in_flight?
        response = PensionBurial::Service.new.status(guid)
        if response.success?
          map_downstream_status(response.body)
          save!
        else
          log_message_to_sentry('Error getting status from Central Mail API',
                                :warning,
                                status: response.status,
                                body: response.body)
          raise Common::Exceptions::BadGateway
        end
      end
    end

    private

    def rewrite_url(url)
      rewritten = url.sub!(Settings.vba_documents.location.prefix, Settings.vba_documents.location.replacement)
      raise 'Unable to provide document upload location' unless rewritten
      rewritten
    end

    def signed_url(guid)
      s3 = Aws::S3::Resource.new(region: Settings.vba_documents.s3.region,
                                 access_key_id: Settings.vba_documents.s3.aws_access_key_id,
                                 secret_access_key: Settings.vba_documents.s3.aws_secret_access_key)
      obj = s3.bucket(Settings.vba_documents.s3.bucket).object(guid)
      obj.presigned_url(:put, {})
    end

    def status_in_flight?
      IN_FLIGHT_STATUSES.include?(status)
    end

    def map_downstream_status(body)
      response_object = JSON.parse(body)[0][0]
      if response_object['status'] == 'Received'
        self.status = 'received'
      elsif response_object['status'] == 'In Process'
        self.status = 'processing'
      elsif response_object['status'] == 'Success'
        self.status = 'success'
      elsif response_object['status'] == 'Error'
        self.status = 'error'
        self.code = 'DOC202'
        self.detail = "Downstream status: #{response_object['errorMessage']}"
      else
        log_message_to_sentry('Unknown status value from Central Mail API',
                              :warning,
                              status: response_object['status'])
        raise Common::Exceptions::BadGateway, detail: 'Unknown processing status'
      end
    end
  end
end
