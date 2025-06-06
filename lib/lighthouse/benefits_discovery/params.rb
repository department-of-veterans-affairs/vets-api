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
        discharge_status: ,
        branch_of_service: ,
        disability_rating: ?,
        service_start_date: ,
        service_end_date:
      }
    end

    private

    
  end
end
