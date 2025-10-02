# frozen_string_literal: true

require 'lighthouse/facilities/v1/client'

module MyHealth
    module FacilitiesHelper
        module_function

        def set_health_care_system_names(triage_teams)
            facility_ids = triage_teams.map(&:station_number).uniq
            facility_map = get_facility_map(facility_ids)

            triage_teams.each do |team|
                if team.health_care_system_name.nil? || team.health_care_system_name.empty?
                    team.health_care_system_name = facility_map[team.station_number]
                end
            end
            triage_teams
        end

        def get_facility_map(facility_ids)
            converted_facility_ids = convert_non_prod_ids(facility_ids)
            facilities = get_facilities(converted_facility_ids)
            facility_map = facilities.each_with_object({}) do |facility, map|
                id = deconvert_non_prod_id(facility.id.sub(/^vha_/, ''))
                map[id] = facility.name
            end

            facility_map
        end

        def get_facilities(facility_ids)
            facilities_service.get_facilities(facilityIds: facility_ids.to_a.map { |id| "vha_#{id}" }.join(','))
        end

        def convert_non_prod_ids(ids)
            return ids if Settings.hostname == 'api.va.gov'
            ids.map{|id|
                id 
                case id
                when '979'
                    '552'
                when '989'
                    '442'
                else
                    id
                end
            }
        end

        def deconvert_non_prod_id(id)
            return id if Settings.hostname == 'api.va.gov'
            case id
            when '552'
                '979'
            when '442'
                '989'
            else
                id
            end
        end

        def facilities_service
            Lighthouse::Facilities::V1::Client.new
        end
    end
end