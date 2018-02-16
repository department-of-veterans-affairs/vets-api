# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'rx/configuration'
require 'rx/client_session'
require 'active_support/core_ext/hash/slice'

module Facilities
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    configuration Facilities::Configuration

    def get_all_vha
      get_all_facilities 'VHA_Facilities', 'StationNumber'
    end

    def get_all_nca
      get_all_facilities 'NCA_Facilities', 'SITE_ID'
    end

    def get_all_vba
      get_all_facilities 'VBA_Facilities', 'Facility_Number'
    end

    def get_all_vc
      get_all_facilities 'VHA_VetCenters', 'stationno'
    end

    private

    def get_all_facilities(facility_type, order_field)
      query = ['where=1=1', 'nSR=4326', 'outSR=4326', 'returnGeometry=true', 'returnCountOnly=false',
               'outFields=%2A', 'returnDistinctValues=false', 'f=json', "orderByFields=#{order_field}"]
      path = '/FeatureServer/0/query?'
      json = perform(:get, facility_type + path + query.join('&'), nil).body
      JSON.parse json
    end
  end
end
