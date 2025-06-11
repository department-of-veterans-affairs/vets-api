# frozen_string_literal: true

module BenefitsDiscovery
  class Params
    # dateOfBirth	user.birth_date
    # dischargeStatus	character_of_discharge_code?
    # branchOfService	branch_of_service
    # disabilityRating	[...]
    # serviceDates	begin_date && end_date
    # purpleHeartRecipientDates	[...]
    def initialize(user_uuid)
      # this is probably not correct
      @user = User.find(user_uuid)
    end

    def prepared_params
      {
        dateOfBirth: @user.birth_date,
        dischargeStatus: service_history.collect(&:character_of_discharge_code),
        branchOfService: service_history.collect(&:branch_of_service),
        disabilityRating: disability_rating,
        serviceDates: service_history.collect { |sh| { beginDate: sh.begin_date, endDate: sh.end_date } }
        # purpleHeartRecipientDates: Array.wrap(params[:purple_heart_recipient_dates])
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
  end
end
