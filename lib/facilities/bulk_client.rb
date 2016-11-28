# frozen_string_literal: true
require 'facilities/gis_middleware'

# Client class for doing periodic bulk refreshes of GIS data.
# Allows inspection of last modified date to update only when needed.
module Facilities
  class BulkClient
    BATCH_SIZE = 1000.0
    OPEN_TIMEOUT = 2
    REQUEST_TIMEOUT = 6

    COUNT_PARAMS = {
      where: '1=1',
      returnCountOnly: true,
      f: 'json'
    }.freeze

    ALL_PARAMS = {
      where: '1=1',
      inSR: 4326,
      outSR: 4326,
      returnGeometry: true,
      outFields: '*',
      f: 'json'
    }.freeze

    def initialize(url)
      @url = url
      @conn = Faraday.new(url: @url) do |conn|
        conn.options.open_timeout = OPEN_TIMEOUT
        conn.options.timeout = REQUEST_TIMEOUT
        conn.response Facilities::Middleware::GISJson
        # conn.response :logger
        # TODO conn.use :breaker
        conn.adapter Faraday.default_adapter
      end
    end

    def last_edit_date
      response = @conn.get('', f: 'json')
      response.body.dig('editingInfo', 'lastEditDate')
    rescue Faraday::ConnectionFailed => e
      Rails.logger.warn "Facility lastEditDate check connection failed: #{e.message}"
      return nil
    rescue Faraday::TimeoutError
      Rails.logger.warn 'Facility lastEditDate check timeout'
      return nil
    rescue Facilities::Errors::ServiceError => e
      Rails.logger.warn "Facility lastEditDate check request failed: #{e.message}"
      return nil
    end

    def fetch_all
      Rails.logger.info "Refreshing from #{@url}"
      query_url = [@url, 'query'].join('/')
      count = get_count(query_url)
      fetch_in_batches(query_url, count) unless count.nil?
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error "Facility fetch connection failed: #{e.message}"
      raise Facilities::Errors::ServiceError, 'Facility connection failed'
    rescue Faraday::TimeoutError
      Rails.logger.error 'Facility fetch timeout'
      raise Facilities::Errors::ServiceError, 'Facility connection timed out'
    rescue Facilities::Errors::ServiceError => e
      Rails.logger.error "Facility fetch request failed: #{e.message}"
      raise
    end

    def get_count(url)
      response = @conn.get url, COUNT_PARAMS
      response.body.dig('count')
    end

    def fetch_in_batches(url, count)
      max = (count / BATCH_SIZE).ceil - 1
      facilities = []
      (0..max).each do |i|
        batch_params = {
          resultOffset: (i * BATCH_SIZE).to_i,
          resultRecordCount: BATCH_SIZE.to_i
        }
        response = @conn.get url, ALL_PARAMS.merge(batch_params)
        facilities += response.body.dig('features').to_a
      end
      facilities
    end
  end
end
