# frozen_string_literal: true

module TravelPay
  class SmocService
    def initialize(auth_manager, user)
      @auth_manager = auth_manager
      @user = user
    end

    ##
    # Submits a mileage-only claim to the Travel Pay API.
    # @params:
    #  {
    #   appointment_date_time: datetime string ('2024-01-01T12:45:34.465Z'),
    #   facility_station_number: string (i.e. facilityId),
    #   appointment_name: string, **Optional - but will fail if passed an empty string
    #   appointment_type: string, 'CompensationAndPensionExamination' || 'Other'
    #   is_complete: boolean,
    #  }
    #
    # @returns the claim ID and status
    # {
    #   'claimId' => string (UUID),
    #   'status' => string ('Claim submitted' || 'Saved' || 'Incomplete'),
    # }
    #
    #
    def submit_mileage_expense(params) # rubocop:disable Metrics/MethodLength
      Rails.logger.info(message: 'SMOC transaction START')
      claim = get_claim_id(params)

      Rails.logger.info(message: "SMOC transaction: Add expense to claim #{claim['claimId'].slice(0, 8)}")
      expense = expenses_service.add_expense({ 'claim_id' => claim['claimId'],
                                               'appt_date' => params['appointment_date_time'] })

      Rails.logger.info(message: "SMOC transaction: Submit claim #{claim['claimId'].slice(0, 8)}")
      submitted_claim = claims_service.submit_claim(claim['claimId'])
      submitted_claim['status'] = 'Claim submitted'

      submitted_claim
    rescue ArgumentError => e
      raise Common::Exceptions::BadRequest, detail: e.message
    rescue => e
      if claim.nil? ## error occurred on claim creation step
        Rails.logger.error(message: 'SMOC transaction: Failed to create claim')
        raise Common::Exceptions::BackendServiceException.new(nil, {}, detail: 'Failed to create claim')
      elsif expense.nil? && claim['claimId'].present? ## error occurred on expense step, but claim was created
        Rails.logger.error(message: "SMOC transaction: Failed to add expense, #{e}")
        {
          'claimId' => claim['claimId'],
          'status' => 'Incomplete'
        }
      else
        expense['expenseId'].present? ## error occurred on submit step, but claim was created and expense was added
        Rails.logger.error(message: "SMOC transaction: Failed to submit claim #{claim['claimId'].slice(
          0, 8
        )}")
        {
          'claimId' => claim['claimId'],
          'status' => 'Saved'
        }
      end
    end

    private

    def get_appt_or_raise(params)
      appt_not_found_msg = "No appointment found for #{params['appointment_date_time']}"
      Rails.logger.info(message:
                        "SMOC transaction: Get appt by date time: #{params['appointment_date_time']}")
      appt = appts_service.find_or_create_appointment(params)

      if appt[:data].nil?
        Rails.logger.error(message: appt_not_found_msg)
        raise Common::Exceptions::ResourceNotFound, detail: appt_not_found_msg
      end

      appt[:data]['id']
    end

    def get_claim_id(params)
      appt_id = get_appt_or_raise(params)
      Rails.logger.info(message: 'SMOC transaction: Create claim')
      claims_service.create_new_claim({ 'btsss_appt_id' => appt_id })
    end

    def claims_service
      @claims_service ||= TravelPay::ClaimsService.new(@auth_manager, @user)
    end

    def appts_service
      @appts_service ||= TravelPay::AppointmentsService.new(@auth_manager)
    end

    def expenses_service
      @expenses_service ||= TravelPay::ExpensesService.new(@auth_manager)
    end
  end
end
