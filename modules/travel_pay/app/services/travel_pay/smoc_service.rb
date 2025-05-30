# frozen_string_literal: true

module TravelPay
  class SmocService
    def initialize(auth_manager, user)
      @auth_manager = auth_manager
      @user = user
    end

    def submit_mileage_expense(params) # rubocop:disable Metrics/MethodLength
      Rails.logger.info(message: 'SMOC transaction START')
      claim_id = get_claim_id(params)

      Rails.logger.info(message: "SMOC transaction: Add expense to claim #{claim_id.slice(0, 8)}")
      expense = expenses_service.add_expense({ 'claim_id' => claim_id,
                                               'appt_date' => params['appointment_date_time'] })

      Rails.logger.info(message: "SMOC transaction: Submit claim #{claim_id.slice(0, 8)}")
      submitted_claim = claims_service.submit_claim(claim_id)
      submitted_claim['status'] = 'Claim submitted'

      submitted_claim
    rescue => e
      if expense.present? ## error occurred on submit step, but claim was created and expense was added
        Rails.logger.error(message: "SMOC transaction: Failed to submit claim #{claim_id.slice(
          0, 8
        )}")
        {
          'claimId' => claim_id,
          'status' => 'Saved'
        }
      elsif claim_id.present? ## error occurred on expense step, but claim was created
        Rails.logger.error(message: "SMOC transaction: Failed to add expense, #{e}")
        {
          'claimId' => claim_id,
          'status' => 'Incomplete'
        }
      else
        Rails.logger.error(message: "SMOC transaction: Failed to create claim, #{e}")
        rescue_errors(e)
      end
    end

    private

    def get_appt_or_raise(params)
      appt_not_found_msg = "No appointment found for #{params['appointment_date_time']}"
      Rails.logger.info(message:
                        "SMOC transaction: Get appt by date time: #{params['appointment_date_time']}")
      appt = appts_service.find_or_create_appointment(params)

      if appt['id'].nil?
        Rails.logger.error(message: appt_not_found_msg)
        raise Common::Exceptions::ResourceNotFound, detail: appt_not_found_msg
      end

      appt['id']
    end

    def get_claim_id(params)
      appt_id = get_appt_or_raise(params)
      claim_creation_error_msg = "Failed to create claim for appointment ID #{appt_id.slice(
        0, 8
      )}"
      Rails.logger.info(message: 'SMOC transaction: Create claim')
      claim = claims_service.create_new_claim({ 'btsss_appt_id' => appt_id })

      # TODO: Currently no error handling in claims_service.create_new_claim
      if claim.nil? || claim['claimId'].nil?
        Rails.logger.error(message: "SMOC transaction: #{claim_creation_error_msg}")
        raise Common::Exceptions::BackendServiceException.new(nil, detail: claim_creation_error_msg)
      end
      claim['claimId']
    end

    def rescue_errors(e)
      if e.is_a?(ArgumentError) || e.is_a?(InvalidComparableError)
        Rails.logger.error(message: e.message.to_s)
        raise Common::Exceptions::BadRequest, detail: e.message
      else
        Rails.logger.error(message: "An error occurred: #{e}")
        raise Common::Exceptions::InternalServerError, exception: e
      end
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
