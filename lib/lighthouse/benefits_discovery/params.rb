# frozen_string_literal: true

module BenefitsDiscovery
  class Params
    def initialize(user_uuid)
      @user = User.find(user_uuid)
      raise Common::Exceptions::RecordNotFound, user_uuid if @user.nil?
    end

    def prepared_params(service_history_params)
      {
        dateOfBirth: @user.birth_date,
        disabilityRating: disability_rating
      }.merge(service_history_params).compact_blank
    end

    class << self
      # may be wise to rescue in order to ensure we don't introduce errors
      def service_history_params(service_history)
        episodes = service_history.episodes
        {
          dischargeStatus: discharge_status(episodes),
          branchOfService: episodes.map { |sh| sh.branch_of_service&.upcase },
          serviceDates: episodes.map { |sh| { beginDate: sh.begin_date, endDate: sh.end_date } }
        }.compact_blank
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

    private

    def disability_rating
      service = VeteranVerification::Service.new
      response = service.get_rated_disabilities(@user.icn)
      response.dig('data', 'attributes', 'combined_disability_rating')
    end
  end
end
