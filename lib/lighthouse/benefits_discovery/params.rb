# frozen_string_literal: true

module BenefitsDiscovery
  class Params
    def initialize(user_uuid)
      @user = User.find(user_uuid)
    end

    def prepared_params
      {
        dateOfBirth: @user.birth_date,
        dischargeStatus: discharge_status,
        branchOfService: service_history.collect { |sh| sh.branch_of_service&.upcase },
        disabilityRating: disability_rating,
        serviceDates: service_history.collect { |sh| { beginDate: sh.begin_date, endDate: sh.end_date } }
      }.compact_blank
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
      discharge_codes = service_history.collect(&:character_of_discharge_code)
      # log error if no match
      discharges = discharge_codes.map { |b| VAProfile::Prefill::MilitaryInformation::DISCHARGE_TYPES[b] }
      discharges.map { |d| "#{d.upcase.gsub('-', '_')}_DISCHARGE" }
    end
  end
end
