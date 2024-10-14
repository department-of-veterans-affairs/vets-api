# frozen_string_literal: true

module TravelPay
  class ClaimAssociationService
    ## @params
    # appointments: [VAOS::Appointment]
    # start_date: string
    # end_date: string
    #
    # @returns
    # appointments: [VAOS::Appointment + associatedTravelPayClaim (string)]

    def associate_appointments_to_claims(tokens, params = {})
      # We need to associate an existing claim to a VAOS appointment, matching on date-time & facility
      #
      # So there will be a 1:1 claimID > appt association
      #
      # Will return a new array:
      #
      # VAOS::Appointment
      #   + if date/facility match (indicating a related claim has already been filed for that date)
      #       associatedTravelPayClaim => claimId (string)

      # Get claims for the specified date range
      raw_claims = service.get_claims_by_date_range(*tokens,
                                                    { 'start_date' => params['start_date'],
                                                      'end_date' => params['end_date'] })

      # If no claims for the selected range, just return the original appointments
      return params['appointments'] unless raw_claims.count?

      # map over the appointments list and the raw_claims and match dates
      (params['appointments']).map do |appt|
        raw_claims['data'].each do |cl|
          if Date.parse(cl['appointmentDateTime']) == Date.parse(appt['startDate']) &&
             cl['facilityName'] == appt['facilityName']
            # Add the new attribute "associatedTravelPayClaim" => claim ID to the appt hash
            appt[:associatedTravelPayClaim] = cl[:id]
          else
            # if no claims match, return the original unaltered appointment
            appt
          end
        end
      end
    end

    private

    def service
      TravelPay::ClaimsService.new
    end
  end
end
