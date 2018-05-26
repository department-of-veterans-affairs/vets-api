# frozen_string_literal: true

module VBADocuments
  class UploadSubmission < ActiveRecord::Base
    include SetGuid
    include SentryLogging

    IN_FLIGHT_STATUSES = %w[received processing].freeze

    def self.refresh_and_get_statuses!(guids)
      submissions = where(guid: guids)
      in_flights = submissions.select { |sub| sub.send(:status_in_flight?) }
      refresh_statuses!(in_flights)
      missing = guids - submissions.map(&:guid)
      submissions.to_a + missing.map { |id| fake_status(id) }
    end

    def self.fake_status(guid)
      empty_submission = OpenStruct.new(guid: guid,
                                        status: 'error',
                                        code: 'DOC105',
                                        detail: VBADocuments::UploadError::DOC105,
                                        location: nil)
      def empty_submission.read_attribute_for_serialization(attr)
        self.send(attr)
      end
      empty_submission
    end

    def self.refresh_statuses!(submissions)
      guids = submissions.map(&:guid)
      return if guids.empty?
      response = PensionBurial::Service.new.status(guids)
      if response.success?
        statuses = JSON.parse(response.body)
        updated = statuses.select { |stat| stat.dig(0, 'uuid').present? }.map do |stat|
          sub = submissions.select { |s| s.guid == stat[0]['uuid'] }.first
          sub.send(:map_downstream_status, stat[0])
          sub
        end
        ActiveRecord::Base.transaction { updated.each(&:save!) }
      else
        submissions.first.log_message_to_sentry('Error getting status from Central Mail API',
                                                :warning,
                                                status: response.status,
                                                body: response.body)
        raise Common::Exceptions::BadGateway
      end
    end

    def refresh_status!
      if status_in_flight?
        response = PensionBurial::Service.new.status(guid)
        if response.success?
          response_object = JSON.parse(response.body)[0][0]
          map_downstream_status(response_object)
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

    def get_location
      rewrite_url(signed_url(guid))
    end

    def consumer_name
      self[:consumer_name] || 'unknown'
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

    def map_downstream_status(response_object)
      if response_object.blank?
        log_message_to_sentry('Empty status response for known UUID from Central Mail API', :warning)
        return
      end
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
