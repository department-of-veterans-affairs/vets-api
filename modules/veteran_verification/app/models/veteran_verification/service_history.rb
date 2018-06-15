module VeteranVerification
  class ServiceHistory
    include Enumerable
    delegate :service_episodes_by_date, :deployments, to: :emis
    delegate :each, to: :formated_episodes

    def self.from_user(user)
      self.new EMISRedis::MilitaryInformation.for_user(@current_user)
    end

    def initialize(emis_military_information)
      @emis = emis_military_information
      handle_errors!
    end

    def formated_episodes
      @episodes ||= service_episodes_by_date.map do |episode|
        deps = deployments.filter do |dep|
          dep.begin_date >= episode.begin_date and dep.end_date <= episode.end_date
        end.map do |dep|
          {
            start_date: dep.begin_date
            end_date: dep.end_date
            location: dep.locations[0].iso_alpha3_country
          }
        end
        {
          branch_of_service: @emis.build_service_branch(episode.branch_of_service)
          start_date: episode.begin_date
          end_date: episode.end_date
          discharge_status: discharge_type(episode)
          deployments: deps
      end
    end

    def deployments_by_date
      @deployments_by_date ||= lambda do
        deployments_by_date.sort_by { |ep| ep.end_date || Time.zone.today + 3650 }.reverse
      end.call
    end

    def dischage_type(service_episode)
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
