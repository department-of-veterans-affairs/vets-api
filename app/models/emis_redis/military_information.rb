# frozen_string_literal: true
module EMISRedis
  class MilitaryInformation < Model
    CLASS_NAME = 'MilitaryInformationService'

    def last_branch_of_service
      binding.pry; fail
      emis_response('get_military_service_episodes').items
    end

    def service_episodes_by_date
      @service_episodes_by_date ||= lambda do
        service_episodes = emis_response('get_military_service_episodes')
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

