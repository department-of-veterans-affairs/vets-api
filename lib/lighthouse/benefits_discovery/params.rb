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
      @user = User.find_by(uuid: user_uuid)
    end

    def prepared_params
      {
        date_of_birth: @user.birth_date,
        discharge_status: service_history.character_of_discharge_code,
        branch_of_service: service_history.branch_of_service,
        disability_rating: ,
        service_start_date: service_history.begin_date,
        service_end_date: service_history.end_date
      }
    end

    private

    def disability_rating
      service = VeteranVerification::Service.new
      service.get_rated_disabilities(@user.icn)
    end

    def service_history
      service = VAProfile::MilitaryPersonnel::Service.new
      response = service.get_service_history
      json = JSON.parse(response.episodes.to_json, symbolize_names: true)

      # service = VAProfile::MilitaryPersonnel::Service.new(@current_user)
      # response = service.get_service_history
    end
  end
end
