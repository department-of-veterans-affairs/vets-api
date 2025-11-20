# frozen_string_literal: true

require 'lighthouse/facilities/v1/client'

module MyHealth
  module FacilitiesHelper
    module_function

    COMPLICATED_SYSTEMS = {
      '528' => 'VA New York state health care (multiple facilities)',
      '589' => 'VA Kansas and Missouri health care (multiple facilities)',
      '620' => 'VA Hudson Valley New York health care (multiple facilities)',
      '626' => 'VA Tennessee health care (multiple facilities)',
      '636' => 'VA Nebraska and Iowa health care (multiple facilities)',
      '657' => 'VA Missouri and Illinois health care (multiple facilities)',
      '612' => 'VA Northern California (multiple facilities)',
      '612A4' => 'VA Northern California (multiple facilities)'
    }.freeze
    def set_health_care_system_names(all_triage_teams_collection)
      triage_teams = all_triage_teams_collection.records
      triage_teams.each do |team|
        station_number = convert_non_prod_id(team.station_number)
        station_number = convert_prod_id(station_number)
        team.health_care_system_name = COMPLICATED_SYSTEMS[station_number] || team.health_care_system_name
        team.station_number = station_number
      end
      all_triage_teams_collection
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

    def convert_prod_id(id)
      case id
      when '612'
        '612A4'
      else
        id
      end
    end
  end
end
