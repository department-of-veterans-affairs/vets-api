# frozen_string_literal: true

module TravelPay
  class ClaimAssociationService
    ## @params
    # appointments: [VAOS::Appointment]
    # start_date: string
    # end_date: string
    #
    # @returns
    # appointments: [VAOS::Appointment + TravelPay::Claim (optional) + associatedTravelPayClaim (optional)]

    def associate_appointments_to_claims(tokens, params = {})
      # We need to association an existing claim to a VAOS appointment, matching on date-time & facility
      # We also need to associate any existing claims to all VAOS appointments for that date & facility
      #
      # So there will be a 1:1 claim/appt for the first appt of the day (if multiple)
      # Plus a 1:many association of claim:all appts for the day/facility
      #
      # Will return a new array:
      #
      # VAOS::Appointment
      #   + if exact date-time match:
      #       travelPayClaim => TravelPay::Claim
      #   + if only date/facility match (indicating a related claim has already been filed for that date)
      #       associatedTravelPayClaim => claimId (string)

      # Get claims for the specified date range
      raw_claims = client.get_claims_by_date(*tokens, params)

      # If no claims for the selected range, just return the original appointments
      return params['appointments'] unless raw_claims.count?

      # map over the appointments list and the raw_claims and match dates
      (params['appointments']).map do |appt|
        raw_claims['data'].each do |cl|
          # if it's an exact date-time match
          if DateTime.parse(cl['appointmentDateTime']) == DateTime.parse(appt['startDate'])
            # Add the claim object to the appt. hash
            # Add a new attribute of "associatedTravelPayClaim" => claim ID to the appt hash
            appt[:associatedTravelPayClaim] = cl[:id]
            appt[:travelPayClaim] = cl
            # if it's not an exact match, but on the same day at the same facility,
          elsif Date.parse(cl['appointmentDateTime']) == Date.parse(appt['startDate']) &&
                cl['facilityName'] == appt['facilityName']
            # Add the new attribute "associatedTravelPayClaim" => claim ID to the appt hash but not the entire claim
            appt[:associatedTravelPayClaim] = cl[:id]
          else
            # if no claims match, return the original unaltered appointment
            appt
          end
        end
      end
    end

    private

    def client
      TravelPay::ClaimsClient.new
    end
  end
end
