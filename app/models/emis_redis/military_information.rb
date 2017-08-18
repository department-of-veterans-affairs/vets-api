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

    def last_branch_of_service
      return if service_episodes_by_date.blank?

      SERVICE_BRANCHES[service_episodes_by_date[0].branch_of_service_code] || 'other'
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

