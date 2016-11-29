# frozen_string_literal: true
require 'facilities/bulk_client'
require 'facilities/point'

module Facilities
  class LocalStore
    attr_reader :adapter

    GIS_CHECK_FREQUENCY = 1.hour

    def initialize(url, _type, adapter)
      @url = url
      @adapter = adapter
      @mutex = Mutex.new
      @last_check = Time.new(0).utc
      @current_gis_update = 0
      @client = BulkClient.new(@url)
      @index = {}
      @coordinates = []
    end

    def get(id)
      check_freshness_and_update
      @mutex.synchronize do
        return @index[id]
      end
    end

    def query(bbox, services = nil)
      check_freshness_and_update
      @mutex.synchronize do
        result = @coordinates.select { |p| p.within?(bbox) }
        result = result.sort_by { |p| p.dist_from_center(bbox) }
        result = result.map(&:facility)
        if services
          result = result.select { |f| @adapter.services?(f, services) }
        end
        result
      end
    end

    def check_freshness_and_update
      return unless Time.current > (@last_check + GIS_CHECK_FREQUENCY)
      @mutex.synchronize do
        return unless Time.current > (@last_check + GIS_CHECK_FREQUENCY)
        last_edit = @client.last_edit_date
        return if up_to_date?(last_edit)
        begin
          facilities = @client.fetch_all
          return if facilities.to_a.empty?
          Rails.logger.debug "Indexing #{facilities.length} facilities"
          index(facilities.map { |x| @adapter.from_gis x })
          @last_check = Time.current
          @current_gis_update = last_edit
        rescue Facilities::Errors::ServiceError => e
          log_error e
        rescue => e
          log_error e
        end
      end
    end

    # Decide whether current stored data is up to date w.r.t. to retrieved lastEditDate
    # Additionally, if we could not retrieve lastEditDate and we have _some_ data to
    # work with, then set last_check timestamp and try again at next interval.
    def up_to_date?(last_edit)
      Rails.logger.debug "Currently have data #{@current_gis_update}, latest is #{last_edit}"
      @last_check = Time.current if last_edit.nil? && @current_gis_update.nonzero?
      @current_gis_update == last_edit
    end

    def index(facilities)
      new_index = facilities.each_with_object({}) do |f, index|
        index[f.unique_id] = f
      end
      new_coordinates = facilities.each_with_object([]) do |f, coordinates|
        coordinates << Point.new(f.long, f.lat, f)
      end
      @index = new_index
      @coordinates = new_coordinates
    end

    def log_error(e)
      Rails.logger.error "Unexpected error refreshing facilities: #{e.message}"
      Raven.capture_exception(e) if ENV['SENTRY_DSN'].present?
    end
  end
end
