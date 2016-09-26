# frozen_string_literal: true
require 'geoservices'
require 'openssl'

module Facilities
  class Client
    def initialize(url:, layer:, id_field:)
      @url = url
      @layer = layer
      @id_field = id_field
      @service = Geoservice::MapService.new(url: @url)
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
        resultRecordCount: nil, # limit, numeric
        returnDistinctValues: false,
        orderByFields: 'StationID'
      }
      response = @service.query(@layer, params)
      response['features']
    end

    def get(identifier:)
      # TODO: ActiveRecord.Santizers.ClassMethods.santize_sql_for_conditions
      # looks stronger for complete where clause, but is protected
      where_clause = "#{@id_field}=#{ActiveRecord::Base.sanitize(identifier)}"
      params = {
        where: where_clause,
        inSR: 4326,
        outSR: 4326,
        returnGeometry: true,
        returnCountOnly: false,
        outFields: '*',
        resultRecordCount: nil, # limit, numeric
        returnDistinctValues: false,
        orderByFields: 'StationID'
      }
      response = @service.query(@layer, params)
      response['features']
    end
  end
end
