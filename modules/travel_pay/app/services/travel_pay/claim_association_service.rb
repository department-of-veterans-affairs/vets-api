# frozen_string_literal: true

module TravelPay
  class ClaimAssociationService
    ## @params
    # appointments: [VAOS::Appointment]
    # start_date: string ('2024-01-01T12:45:34.465Z')
    # end_date: string ('2024-01-01T12:45:34.465Z')
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
      #   + if date-time & facility match
      #       associatedTravelPayClaim => claimId (string)

      appointments = []
      # Get claims for the specified date range
      raw_claims = service.get_claims_by_date_range(*tokens,
                                                    { 'start_date' => params['start_date'],
                                                      'end_date' => params['end_date'] })

      # TODO: figure out how to append an error message to appt if claims call fails

      # map over the appointments list and the raw_claims and match dates
      params['appointments']['data'].each do |appt|
        raw_claims[:data].each do |cl|
          # Match the exact date-time of the appointment
          if !cl['appointmentDateTime'].nil? &&
             (DateTime.parse(cl['appointmentDateTime']).to_s == DateTime.parse(appt['start']).to_s)

            # match the facility
            #  cl['facilityName'] == appt['facilityName']
            # Add the new attribute "associatedTravelPayClaim" => claim ID to the appt hash
            appt['associatedTravelPayClaim'] = cl
            break
          else
            # if no claims match, append.... something?
            appt['associatedTravelPayClaim'] = {
              'metadata' => 'No claim found for this appointment' # Appt team requested a string to this effect, actual string TBD
            }
          end
        end
        appointments.push(appt)
      end
      appointments
    end

    private

    def service
      TravelPay::ClaimsService.new
    end
  end
end
