# frozen_string_literal: true

require_dependency 'vba_documents/upload_error'
require_dependency 'vba_documents/sql_support'
require 'central_mail/service'
require 'common/exceptions'

module VBADocuments
  class UploadSubmission < ApplicationRecord
    include SetGuid
    include SentryLogging
    extend SQLSupport
    send(:validates_uniqueness_of, :guid)
    before_save :capture_status_time, if: :status_changed?
    after_find :set_initial_status
    attr_reader :current_status

    IN_FLIGHT_STATUSES = %w[received processing success].freeze

    ALL_STATUSES = IN_FLIGHT_STATUSES + %w[pending uploaded vbms error expired].freeze
    RPT_STATUSES = %w[pending uploaded] + IN_FLIGHT_STATUSES + %w[vbms error expired].freeze

    scope :in_flight, -> { where(status: IN_FLIGHT_STATUSES) }

    after_save :report_errors

    def initialize(attributes = nil)
      super
      @current_status = status
      self.metadata = { 'status' => { @current_status => { 'start' => Time.now.to_i } } }
    end

    def self.fake_status(guid)
      empty_submission = OpenStruct.new(guid: guid,
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

    # data structure
    # [{"status"=>"pending", "elapsed_secs"=>"16", "rowcount"=>7},
    # {"status"=>"processing", "elapsed_secs"=>"45", "rowcount" =>2},
    # {"status"=>"received", "elapsed_secs"=>"45", "rowcount"=>3},
    # {"status"=>"uploaded", "elapsed_secs"=>"22", "rowcount"=>5}]
    def self.avg_status_times(from, to, consumer_name = nil)
      avg_status_sql = avg_sql(consumer_name)
      ActiveRecord::Base.connection_pool.with_connection do |c|
        c.raw_connection.exec_params(avg_status_sql, [from, to]).to_a
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

    def map_upstream_status(response_object)
      case response_object['status']
      when 'Received'
        self.status = 'received'
      when 'In Process', 'Processing Success'
        self.status = 'processing'
      when 'Success'
        self.status = 'success'
      when 'VBMS Complete'
        self.status = 'vbms'
      when 'Error', 'Processing Error'
        self.status = 'error'
        self.code = 'DOC202'
        self.detail = "Upstream status: #{response_object['errorMessage']}"
      else
        log_message_to_sentry('Unknown status value from Central Mail API',
                              :warning,
                              status: response_object['status'])
        raise Common::Exceptions::BadGateway, detail: 'Unknown processing status'
      end
    end

    def report_errors
      key = VBADocuments::UploadError::STATSD_UPLOAD_FAIL_KEY
      StatsD.increment key, tags: ["status:#{code}"] if saved_change_to_attribute?(:status) && status == 'error'
    end

    def set_initial_status
      @current_status = status
    end

    def capture_status_time
      from = @current_status
      to = status
      time = Time.now.to_i
      if metadata.has_key? 'status'
        metadata['status'][from]['end'] = time
        metadata['status'][to] ||= {}
        metadata['status'][to]['start'] = time
      else
        metadata['status'] = {}
        metadata['status'][to] = {}
        metadata['status'][to]['start'] = time
      end
      @current_status = to
    end
  end
end
