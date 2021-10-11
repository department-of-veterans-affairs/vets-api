# frozen_string_literal: true

module Mobile
  module FacilitiesHelper
    module_function

    def get_facilities(facility_ids)
      facilities_service.get_facilities(ids: facility_ids.to_a.map { |id| "vha_#{id}" }.join(','))
    end

    def get_facility_name(facility_id)
      facility = facilities_service.get_facilities(ids: "vha_#{facility_id}")
      if facility[0].nil?
        Rails.logger.info('Mobile: Facility not found?', facility_lookup_results: facility, id: facility_id)
        ''
      else
        facility[0].name
      end
    end

    def facilities_service
      Lighthouse::Facilities::Client.new
    end
  end
end
