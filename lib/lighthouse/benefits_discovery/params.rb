# frozen_string_literal: true

module BenefitsDiscovery
  class Params
    def initialize(user)
      @user = user
    end

    def prepared_params
      {
        dateOfBirth: @user.birth_date,
        disabilityRating: disability_rating,
        serviceHistory: service_history
      }.compact_blank
    end

    # this is a temporary method used for discovery purposes
    def build_from_service_history(service_history_params)
      {
        dateOfBirth: @user.birth_date,
        disabilityRating: disability_rating,
        serviceHistory: service_history_params
      }.compact_blank
    end

    private

    def service_history
      service_history_episodes.filter_map do |sh|
        code = sh.character_of_discharge_code
        if code.present?
          discharge_type = VAProfile::Prefill::MilitaryInformation::DISCHARGE_TYPES[code]
          # we want to know if the code is not found in the DISCHARGE_TYPES
          if discharge_type.nil?
            raise Common::Exceptions::UnprocessableEntity.new(
              detail: "No matching discharge type for: #{code}",
              source: self.class.name
            )
          end
        end
        discharge_status = discharge_type.present? ? "#{discharge_type.upcase.gsub('-', '_')}_DISCHARGE" : nil
        {
          startDate: sh.begin_date,
          endDate: sh.end_date,
          dischargeStatus: discharge_status,
          branchOfService: sh.branch_of_service&.upcase
        }
      end
    end

    def disability_rating
      # guard should be moved to controller once this is being called from a controller
      unless @user.authorize(:lighthouse, :access?)
        Rails.logger.info('BenefitsDiscoveryParams: user does not have lighthouse access')
        return nil
      end

      service = VeteranVerification::Service.new
      response = service.get_rated_disabilities(@user.icn)
      response.dig('data', 'attributes', 'combined_disability_rating')
    end

    def service_history_episodes
      # guard should be moved to controller once this is being called from a controller
      return [] unless @user.authorize(:vet360, :military_access?)

      service = VAProfile::MilitaryPersonnel::Service.new(@user)
      response = service.get_service_history
      response.episodes
    end

    # this is also temporary code used for discovery purposes
    class << self
      def service_history_params(episodes)
        episodes.filter_map do |sh|
          code = sh.character_of_discharge_code
          if code.present?
            discharge_type = VAProfile::Prefill::MilitaryInformation::DISCHARGE_TYPES[code]
            # we want to know if the code is not found in the DISCHARGE_TYPES
            if discharge_type.nil?
              raise Common::Exceptions::UnprocessableEntity.new(
                detail: "No matching discharge type for: #{code}",
                source: self.class.name
              )
            end
          end
          discharge_status = discharge_type.present? ? "#{discharge_type.upcase.gsub('-', '_')}_DISCHARGE" : nil
          {
            startDate: sh.begin_date,
            endDate: sh.end_date,
            dischargeStatus: discharge_status,
            branchOfService: sh.branch_of_service&.upcase
          }
        end
      end
    end
  end
end
