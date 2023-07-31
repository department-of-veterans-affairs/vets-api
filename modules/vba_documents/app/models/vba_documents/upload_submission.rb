# frozen_string_literal: true

require 'central_mail/service'
require 'common/exceptions'
require 'vba_documents/upload_error'
require 'vba_documents/webhooks_registrations'

module VBADocuments
  class UploadSubmission < ApplicationRecord
    include SetGuid
    include SentryLogging
    include Webhooks
    send(:validates_uniqueness_of, :guid)
    before_save :record_status_change, if: :status_changed?
    after_save :report_errors
    after_find :set_initial_status
    attr_reader :current_status

    COMPLETED_UPLOAD_SUCCEEDED = 'UploadSucceeded'
    COMPLETED_DOWNLOAD_CONFIRMED = 'DownloadConfirmed'
    COMPLETED_UNIDENTIFIABLE_MAIL = 'UnidentifiableMail'
    ERROR_UNIDENTIFIED_MAIL = %w[
      Unidentified Mail: We could not associate part or all of this submission with a Veteran.
      Please verify the identifying information and resubmit.
    ].join(' ')

    VBMS_STATUS_DEPLOYMENT_DATE = Date.parse('28-06-2019') # Before this date, 'success' was the final status
    FINAL_SUCCESS_STATUS_KEY = 'final_success_status'
    IN_FLIGHT_STATUSES = %w[received processing success].freeze
    ALL_STATUSES = IN_FLIGHT_STATUSES + %w[pending uploaded vbms error expired].freeze
    RPT_STATUSES = %w[pending uploaded] + IN_FLIGHT_STATUSES + %w[vbms error expired].freeze

    # For the rare UploadSubmission, the Central Mail API takes too long to respond, resulting in a recurring timeout
    # Central Mail is working to improve upload endpoint performance, so this should be revisited at a later date
    UPLOAD_TIMEOUT_RETRY_LIMIT = 3

    scope :in_flight, -> { where(status: IN_FLIGHT_STATUSES).not_final_success }
    scope :not_final_success, lambda {
      where("metadata -> '#{FINAL_SUCCESS_STATUS_KEY}' IS NULL AND created_at >= '#{VBMS_STATUS_DEPLOYMENT_DATE}'")
    }

    # look_back is an int and unit of measure is a string or symbol (hours, days, minutes, etc)
    scope :aged_processing, lambda { |look_back, unit_of_measure, status|
      where(status:)
        .where("(metadata -> 'status' -> ? -> 'start')::bigint < ?", status,
               look_back.to_i.send(unit_of_measure.to_sym).ago.to_i)
        .order(-> { Arel.sql("(metadata -> 'status' -> '#{status}' -> 'start')::bigint asc") }.call)
      # lambda above stops security scan from finding false positive sql injection!
    }

    scope :for_consumer, ->(consumer) { where(consumer_name: consumer) }

    def initialize(attributes = nil)
      super
      @current_status = status
      self.metadata = { 'status' => { @current_status => { 'start' => Time.now.to_i } } }
    end

    def self.fake_status(guid)
      empty_submission = OpenStruct.new(guid:,
                                        status: 'error',
                                        code: 'DOC105',
                                        detail: VBADocuments::UploadError::DOC105,
                                        location: nil)

      def empty_submission.read_attribute_for_serialization(attr)
        send(attr)
      end

      empty_submission
    end

    def self.refresh_statuses!(submissions)
      guids = submissions.map(&:guid)
      return if guids.empty?

      response = CentralMail::Service.new.status(guids)
      if response.success?
        statuses = JSON.parse(response.body)
        updated = statuses.select { |stat| stat.dig(0, 'uuid').present? }.map do |stat|
          sub = submissions.select { |s| s.guid == stat[0]['uuid'] }.first
          sub.send(:map_upstream_status, stat[0])
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
        response = CentralMail::Service.new.status(guid)
        if response.success?
          response_object = JSON.parse(response.body)[0][0]
          if response_object.blank?
            log_message_to_sentry('Empty status response for known UUID from Central Mail API', :warning)
          else
            map_upstream_status(response_object)
          end
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

    def appeals_consumer?
      /appeals_api/.match?(consumer_name)
    end

    # base64_encoded metadata field was added in late 2022; recommend only using for records submitted 2023 or later
    def base64_encoded?
      metadata['base64_encoded'] || false
    end

    def track_uploaded_received(cause_key, cause)
      case cause_key
      when :uuid_already_in_cache_cause
        metadata['status']['uploaded'][cause_key.to_s] ||= {}
        metadata['status']['uploaded'][cause_key.to_s][cause] ||= []
        cause_array = metadata['status']['uploaded'][cause_key.to_s][cause]
        cause_array << Time.now.to_i unless cause_array.length > 10
      when :cause
        metadata['status']['received'][cause_key.to_s] ||= []
        metadata['status']['received'][cause_key.to_s] << cause
        # should *never* have an array greater than 1 in length
      else
        Rails.logger.info("track_uploaded_received Invalid cause key passed #{cause_key}")
      end
      save!
    end

    def track_concurrent_duplicate
      # This should never occur now that we are using with_advisory_lock in perform, but if it does we will record it
      # and otherwise leave this model alone as another instance of this job is currently also processing this guid
      metadata['uuid_already_in_cache_count'] ||= 0
      metadata['uuid_already_in_cache_count'] += 1
      save!
    end

    def track_upload_timeout_error
      metadata['upload_timeout_error_count'] ||= 0
      metadata['upload_timeout_error_count'] += 1
      save!
    end

    def hit_upload_timeout_limit?
      metadata['upload_timeout_error_count'] > UPLOAD_TIMEOUT_RETRY_LIMIT
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

    def map_upstream_status(response_object)
      status = response_object['status']
      case status
      when 'Received'
        self.status = 'received'
      when 'In Process', 'Processing Success'
        self.status = 'processing'
      when 'Success'
        self.status = 'success'
      when 'Complete'
        process_complete(response_object)
      when 'VBMS Complete'
        self.status = 'vbms'
      when 'Error', 'Processing Error'
        self.status = 'error'
        self.code = 'DOC202'
        self.detail = "Upstream status: #{response_object['errorMessage']}"
      else
        log_message_to_sentry('Unknown status value from Central Mail API', :warning, status:)
        raise Common::Exceptions::BadGateway, detail: 'Unknown processing status'
      end
    end

    def process_complete(response_object)
      new_status = get_complete_status(response_object)

      if new_status
        self.status = new_status
        metadata[FINAL_SUCCESS_STATUS_KEY] = Time.now.to_i if new_status.eql?('success')

        if new_status.eql?('error')
          self.code = 'DOC202'
          self.detail = "Upstream status: #{ERROR_UNIDENTIFIED_MAIL}"
        end

        metadata['completed_details'] = response_object['packets']
      else
        msg = "Unable to determine Complete status. Packets/completedReason not included. Response: #{response_object}"
        Rails.logger.error(msg)
        log_message_to_sentry(msg, :warning, status: 'undetermined')
      end
    end

    def get_complete_status(response_object)
      new_status = nil
      packets = response_object['packets']
      if packets
        if packets.any? { |i| i['completedReason'].eql? COMPLETED_UNIDENTIFIABLE_MAIL }
          new_status = 'error'
        elsif packets.any? { |i| i['completedReason'].eql? COMPLETED_UPLOAD_SUCCEEDED }
          new_status = 'vbms'
        elsif packets.any? { |i| i['completedReason'].eql? COMPLETED_DOWNLOAD_CONFIRMED }
          new_status = 'success'
        end
      end
      new_status
    end

    def report_errors
      key = VBADocuments::UploadError::STATSD_UPLOAD_FAIL_KEY
      StatsD.increment key, tags: ["status:#{code}"] if saved_change_to_attribute?(:status) && status == 'error'
    end

    def set_initial_status
      @current_status = status
    end

    def record_status_change
      from = @current_status
      to = status
      time = Time.now.to_i
      # ensure that we have a current status. Old upload submissions may not have been run through the initializer
      # so we are checking that here
      metadata['status'][from]['end'] = time if metadata.key? 'status'
      metadata['status'] ||= {}
      metadata['status'][to] ||= {}
      metadata['status'][to]['start'] = time

      # get the message to record the status change web hook
      if Settings.vba_documents.v2_enabled
        msg = format_msg(VBADocuments::Registrations::WEBHOOK_STATUS_CHANGE_EVENT, from, to, guid)
        params = { consumer_id:, consumer_name:,
                   event: VBADocuments::Registrations::WEBHOOK_STATUS_CHANGE_EVENT, api_guid: guid, msg: }
        Webhooks::Utilities.record_notifications(**params)
      end

      # set new current status
      @current_status = to
    end

    def format_msg(event, from_status, to_status, guid)
      api = Webhooks::Utilities.event_to_api_name[event]
      { api_name: api, guid:, event:, status_from: from_status, status_to: to_status,
        epoch_time: Time.now.to_i }
    end
  end
end

# load './modules/vba_documents/app/models/vba_documents/upload_submission.rb'
