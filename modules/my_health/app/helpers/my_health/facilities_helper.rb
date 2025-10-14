# frozen_string_literal: true

require 'lighthouse/facilities/v1/client'

module MyHealth
  module FacilitiesHelper
    module_function

    def set_health_care_system_names(all_triage_teams_collection)
      triage_teams = all_triage_teams_collection.records
      facility_ids = triage_teams.map(&:station_number).uniq
      triage_teams.each do |team|
        team.station_number = convert_non_prod_id(team.station_number)
      end
      begin
        facility_map = get_facility_map(facility_ids)
        triage_teams.each do |team|
          team.health_care_system_name = facility_map[team.station_number] if team.health_care_system_name.blank?
        end
      rescue => e
        all_triage_teams_collection.metadata[:facility_error] = e.message
      end
      all_triage_teams_collection
    end

    def get_facility_map(facility_ids)
      converted_facility_ids = convert_non_prod_ids(facility_ids)
      facilities = get_facilities(converted_facility_ids)
      facilities.each_with_object({}) do |facility, map|
        id = facility.id.sub(/^vha_/, '')
        map[id] = facility.name
      end
    end

    def get_facilities(facility_ids)
      facilities_service.get_facilities(facilityIds: facility_ids.to_a.map { |id| "vha_#{id}" }.join(','))
    end

    def convert_non_prod_ids(ids)
      return ids if Settings.hostname == 'api.va.gov'

      ids.map do |id|
        convert_non_prod_id(id)
      end
    end

    def convert_non_prod_id(id)
      return id if Settings.hostname == 'api.va.gov'

      case id
      when '979'
        '552'
      when '989'
        '442'
      else
        id
      end
    end

    def facilities_service
      Lighthouse::Facilities::V1::Client.new
    end
  end
end
