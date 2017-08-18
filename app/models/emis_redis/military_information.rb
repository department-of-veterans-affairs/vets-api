# frozen_string_literal: true
module EMISRedis
  class MilitaryInformation < Model
    CLASS_NAME = 'MilitaryInformationService'

    SERVICE_BRANCHES = {
      'F' => "air force",
      'A' => 'army',
      'C' => 'coast guard',
      'M' => "marine corps",
      'N' => 'navy',
      'O' => 'noaa',
      'H' => 'usphs'
    }

    DISCHARGE_TYPES = {
      'A' => 'honorable',
      'B' => 'general',
      'D' => 'bad-conduct',
      'F' => 'dishonorable',
      'J' => 'honorable',
      'K' => 'dishonorable'
    }

    def last_branch_of_service
      return if latest_service_episode.blank?

      SERVICE_BRANCHES[latest_service_episode.branch_of_service_code] || 'other'
    end

    def discharge_type
      return if latest_service_episode.blank?

      DISCHARGE_TYPES[latest_service_episode&.discharge_character_of_service_code] || 'other'
    end

    def last_entry_date
      latest_service_episode&.begin_date&.to_s
    end

    def latest_service_episode
      service_episodes_by_date.try(:[], 0)
    end

    def last_discharge_date
      latest_service_episode&.end_date&.to_s
    end

    def service_episodes_by_date
      @service_episodes_by_date ||= lambda do
        service_episodes = emis_response('get_military_service_episodes')&.items || []
        service_episodes.sort_by do |service_episode|
          service_episode.end_date
        end.reverse
      end.call
    end

    def deployments

      emis_response('get_deployment')
    end
  end
end

