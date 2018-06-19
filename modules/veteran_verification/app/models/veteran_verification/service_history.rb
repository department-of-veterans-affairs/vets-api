module VeteranVerification
  class ServiceHistory
    class ServiceHistoryEpisode
      include ActiveModel::Serialization
      include Virtus.model

      attribute :branch_of_service, String
      attribute :end_date, Date
      attribute :deployments, Array
      attribute :discharge_status, String
      attribute :start_date, Date
    end

    delegate :service_history, :service_episodes_by_date, :deployments, to: :@emis

    def self.for_user(user)
      self.new EMISRedis::MilitaryInformation.for_user(user)
    end

    def initialize(emis_military_information)
      @emis = emis_military_information
    end

    def formatted_episodes
      handle_errors!

      @episodes ||= service_episodes_by_date.map do |episode|
        deps = deployments.select do |dep|
          dep.begin_date >= episode.begin_date and dep.end_date <= episode.end_date
        end.map do |dep|
          {
            start_date: dep.begin_date,
            end_date: dep.end_date,
            location: dep.locations[0].iso_alpha3_country,
          }
        end

        ServiceHistoryEpisode.new(
          branch_of_service: @emis.build_service_branch(episode),
          end_date: episode.end_date,
          deployments: deps,
          discharge_status: discharge_type(episode),
          start_date: episode.begin_date
        )
      end
    end

    def discharge_type(service_episode)
      EMISRedis::MilitaryInformation::DISCHARGE_TYPES[
        service_episode&.discharge_character_of_service_code
      ] || 'other'
    end

    private

    def handle_errors!
      raise_error! unless service_history.is_a?(Array)
    end

    def raise_error!
      raise Common::Exceptions::BackendServiceException.new(
              'EMIS_HIST502',
              source: self.class.to_s
            )
    end
  end
end
