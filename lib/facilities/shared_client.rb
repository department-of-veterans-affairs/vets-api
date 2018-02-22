# frozen_string_literal: true

require 'common/client/base'

module Facilities
  # Core class responsible for api interface operations
  class SharedClient < Common::Client::Base
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
      params = { where: '1=1', inSR: 4326, outSR: 4326, returnGeometry: true, returnCountOnly: false,
                 outFields: '*', returnDistinctValues: false, orderByFields: order_field, f: 'json' }
      perform(:get, "#{facility_type}/FeatureServer/0/query?", params).body
    end
  end
end
