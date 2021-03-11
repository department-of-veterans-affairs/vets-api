# frozen_string_literal: true

require_dependency 'vba_documents/upload_error'
require 'central_mail/service'
require 'common/exceptions'

module VBADocuments
  class UploadSubmission < ApplicationRecord
    include SetGuid
    include SentryLogging
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
      self.metadata = {'status' => {@current_status => {'start' => Time.now.to_i}}}
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

    #data structure
    # [{"status"=>"pending", "elapsed_secs"=>"13"},
    # {"status"=>"processing", "elapsed_secs"=>"76"},
    # {"status"=>"received", "elapsed_secs"=>"51"},
    # {"status"=>"uploaded", "elapsed_secs"=>"30"}]
    def self.avg_status_times(from, to, consumer_name = nil)
      avg_status_sql = %Q(
      select status,
      round(avg(duration)) as elapsed_secs
      from (
        select guid,
          status_key as status,
          consumer_name,
          created_at,
          status_json -> status_key -> 'start' as start_time,
          status_json -> status_key -> 'end' as end_time,
          (status_json -> status_key -> 'end')::INTEGER -
          (status_json -> status_key -> 'start')::INTEGER as duration
        from (
          SELECT guid,
            consumer_name,
            created_at,
            jsonb_object_keys(metadata -> 'status') as status_key,
            metadata -> 'status' as status_json
          from vba_documents_upload_submissions
        ) as n1
        where status_json -> status_key -> 'end' is not null
      ) as closed_statuses
      where 1 = 1
      #{consumer_name ? "and consumer_name = '#{consumer_name}' " : ''}
      and   created_at > $1 and created_at < $2
      group by status
    )
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
      @current_status = self.status
    end

    def capture_status_time
      from = @current_status
      to = status
      time = Time.now.to_i
      self.metadata['status'][from]['end'] = time
      self.metadata['status'][to] ||= {}
      self.metadata['status'][to]['start'] = time
      @current_status = to
    end
  end
end

=begin
#todo delete me
load('./modules/vba_documents/app/models/vba_documents/upload_submission.rb')
=end
