# frozen_string_literal: true
# delete me
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

    # We don't want to check successes before
    # this date as it used to be the endpoint
    VBMS_IMPLEMENTATION_DATE = Date.parse('28-06-2019')
    FINAL_SUCCESS_STATUS_KEY = 'final_success_status'
    IN_FLIGHT_STATUSES = %w[received processing success].freeze
    ALL_STATUSES = IN_FLIGHT_STATUSES + %w[pending uploaded vbms error expired].freeze
    RPT_STATUSES = %w[pending uploaded] + IN_FLIGHT_STATUSES + %w[vbms error expired].freeze

    scope :in_flight, -> { where(status: IN_FLIGHT_STATUSES) }

    # look_back is an int and unit of measure is a string or symbol (hours, days, minutes, etc)
    scope :aged_processing, lambda { |look_back, unit_of_measure, status|
      where(status: status)
        .where("(metadata -> 'status' -> ? -> 'start')::bigint < ?", status,
               look_back.to_i.send(unit_of_measure.to_sym).ago.to_i)
        .order(-> { "(metadata -> 'status' -> '#{status}' -> 'start')::bigint asc" }.call)
      # lambda above stops security scan from finding false positive sql injection!
    }

    scope :has_web_hook_url, -> { where("metadata -> 'web_hook' -> 'url' is not null") }
    scope :web_hook_status_notified, -> (status, bool) {
      where("(metadata -> 'web_hook' -> ? -> 'success')::BOOLEAN = ?", status, bool) }

    # load './modules/vba_documents/app/models/vba_documents/upload_submission.rb'
    # metadata: {web_hook: {url: 'http...', uploaded: {success: false, attempts: {1 => 11254254}}}
    #
    # 	"web_hook": {
    # 		"url": "https://gregger.com",
    # 		"uploaded": {"success": true, "attempts": {"1": 11254254}},
    # 		"received": {"success": false, "attempts": {}},
    # 		"error": {"success": false, "attempts": {}},
    # 		"processing": {"success": false, "attempts": {}},
    # 		"success": {"success": false, "attempts": {}},
    # 		"vbms": {"success": false, "attempts": {}}
    # 	}
    #
    def self.get_web_hook_notifications
      statuses = %w(uploaded received error processing success vbms)
      guids = []
      statuses.each do |status|
        guids << where(status: status).has_web_hook_url.web_hook_status_notified(status, false).pluck(:guid)
      end
      guids.flatten
    end

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
    # [{"status"=>"vbms", "min_secs"=>816, "max_secs"=>816, "avg_secs"=>816, "rowcount"=>1},
    # {"status"=>"pending", "min_secs"=>0, "max_secs"=>23, "avg_secs"=>9, "rowcount"=>7},
    # {"status"=>"processing", "min_secs"=>9, "max_secs"=>22, "avg_secs"=>16, "rowcount"=>2},
    # {"status"=>"success", "min_secs"=>17, "max_secs"=>38, "avg_secs"=>26, "rowcount"=>3},
    # {"status"=>"received", "min_secs"=>10, "max_secs"=>539681, "avg_secs"=>269846, "rowcount"=>2},
    # {"status"=>"uploaded", "min_secs"=>0, "max_secs"=>21, "avg_secs"=>10, "rowcount"=>6}]
    def self.status_elapsed_times(from, to, consumer_name = nil)
      avg_status_sql = status_elapsed_time_sql(consumer_name)
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
      # ensure that we have a current status. Old upload submissions may not have been run through the initializer
      # so we are checking that here
      metadata['status'][from]['end'] = time if metadata.key? 'status'
      metadata['status'] ||= {}
      metadata['status'][to] ||= {}
      metadata['status'][to]['start'] = time
      @current_status = to
    end
  end
end

# load './modules/vba_documents/app/models/vba_documents/upload_submission.rb'