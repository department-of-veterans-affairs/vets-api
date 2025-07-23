# frozen_string_literal: true

module BenefitsDiscovery
  class Params
    def initialize(user)
      @user = user
    end

    def prepared_params
      {
        dateOfBirth: @user.birth_date,
        dischargeStatus: discharge_status,
        branchOfService: service_history.map { |sh| sh.branch_of_service&.upcase },
        disabilityRating: disability_rating,
        serviceDates: service_history.map { |sh| { beginDate: sh.begin_date, endDate: sh.end_date } }
      }.compact_blank
    end

    # this is a temporary method used for discovery purposes
    def build_from_service_history(service_history_params)
      {
        dateOfBirth: @user.birth_date,
        disabilityRating: disability_rating
      }.merge(service_history_params).compact_blank
    end

    private

    def disability_rating
      service = VeteranVerification::Service.new
      response = service.get_rated_disabilities(@user.icn)
      response.dig('data', 'attributes', 'combined_disability_rating')
    end

    def service_history
      @service_history ||= begin
        service = VAProfile::MilitaryPersonnel::Service.new(@user)
        response = service.get_service_history
        response.episodes
      end
    end

    def discharge_status
      service_history.map do |sh|
        code = sh[:character_of_discharge_code]
        discharge_type = VAProfile::Prefill::MilitaryInformation::DISCHARGE_TYPES[code]
        if discharge_type.nil?
          Rails.logger.error("No matching discharge code for: #{discharge_type}")
          nil
        else
          "#{discharge_type.upcase.gsub('-', '_')}_DISCHARGE"
        end
      end.compact
    end

    # this is also temporary code used for discovery purposes
    class << self
      def service_history_params(service_history_episodes)
        {
          dischargeStatus: discharge_status(service_history_episodes),
          branchOfService: service_history_episodes.map { |sh| sh.branch_of_service&.upcase },
          serviceDates: service_history_episodes.map { |sh| { beginDate: sh.begin_date, endDate: sh.end_date } }
        }
      end

      private

      def discharge_status(episodes)
        episodes.map do |sh|
          code = sh[:character_of_discharge_code]
          discharge_type = VAProfile::Prefill::MilitaryInformation::DISCHARGE_TYPES[code]
          if discharge_type.nil?
            Rails.logger.error("No matching discharge code for: #{discharge_type}")
            nil
          else
            "#{discharge_type.upcase.gsub('-', '_')}_DISCHARGE"
          end
        end.compact
      end
    end
  end
end
