# frozen_string_literal: true

require 'typhoeus'

module Facilities
  class Client
    REQUEST_TIMEOUT = 6

    def initialize(url:, id_field:)
      @url = [url, 'query'].join('/')
      @id_field = id_field
    end

    def query(bbox:, where: nil)
      params = {
        geometry: bbox,
        geometryType: 'esriGeometryEnvelope',
        where: where,
        inSR: 4326,
        outSR: 4326,
        returnGeometry: true,
        returnCountOnly: false,
        outFields: '*',
        returnDistinctValues: false,
        orderByFields: @id_field,
        f: 'json'
      }
      Typhoeus::Request.new(@url, params: params, timeout: REQUEST_TIMEOUT,
                                  connecttimeout: REQUEST_TIMEOUT)
    end

    def get(id:)
      # TODO: ActiveRecord.Santizers.ClassMethods.santize_sql_for_conditions
      # looks stronger for complete where clause, but is protected
      where_clause = "#{@id_field}=#{ActiveRecord::Base.sanitize(id)}"
      params = {
        where: where_clause,
        inSR: 4326,
        outSR: 4326,
        returnGeometry: true,
        returnCountOnly: false,
        outFields: '*',
        returnDistinctValues: false,
        orderByFields: @id_field,
        f: 'json'
      }
      Typhoeus::Request.new(@url, params: params, timeout: REQUEST_TIMEOUT,
                                  connecttimeout: REQUEST_TIMEOUT)
    end
  end
end
