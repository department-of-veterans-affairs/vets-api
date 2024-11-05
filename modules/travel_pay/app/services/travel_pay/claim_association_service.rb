# frozen_string_literal: true

module TravelPay
  class ClaimAssociationService
    # We need to associate an existing claim to a VAOS appointment, matching on date-time
    #
    # There will be a 1:1 claimID > appt association
    #
    # Will return a new array:
    #
    # VAOS::Appointment
    #   +  associatedTravelPayClaim => {
    #         metadata => {
    #           status => int (http status code, i.e. 200)
    #           success => boolean
    #           message => string ('No claim for this appt' | 'Claim service is unavailable')
    #         }
    #         claim => TravelPay::Claim (if a claim matches)
    #   }
    #
    # @params
    # appointments: [VAOS::Appointment]
    # start_date: string ('2024-01-01T12:45:00Z')
    # end_date: string ('2024-02-01T12:45:00Z')
    #
    # @returns
    # appointments: [VAOS::Appointment + associatedTravelPayClaim]

    def associate_appointments_to_claims(params = {})
      raw_claims = service.get_claims_by_date_range(
        { 'start_date' => params['start_date'],
          'end_date' => params['end_date'] }
      )
      if raw_claims
        append_claims(params['appointments']['data'], raw_claims[:data], raw_claims[:metadata])
      else
        append_error(params['appointments']['data'], { 'status' => 503,
                                                       'success' => false,
                                                       'message' => 'Travel Pay service unavailable.' })
      end
    end

    def associate_appointment_to_claim(params = {})
      appt = params['appointment']

      raw_claim = service.get_claims_by_date_range(
        { 'start_date' => appt['start'],
          'end_date' => appt['start'] }
      )
      if raw_claim
        append_single_claim(appt, raw_claim)
      else
        appt['associatedTravelPayClaim'] = {
          'metadata' => { 'status' => 503,
                          'success' => false,
                          'message' => 'Travel Pay service unavailable.' }
        }
        appt
      end
    end

    private

    def append_single_claim(appt, claim_response)
      appt['associatedTravelPayClaim'] = if claim_response[:data].count
                                           {
                                             'metadata' => claim_response[:metadata],
                                             'claim' => claim_response[:data][0]
                                           }
                                         else
                                           {
                                             'metadata' => claim_response[:metadata]
                                           }
                                         end
      appt
    end

    def append_claims(appts, claims, metadata)
      appointments = []
      appts.each do |appt|
        claims.each do |cl|
          if !cl['appointmentDateTime'].nil? &&
             (DateTime.parse(cl['appointmentDateTime']).to_s == DateTime.parse(appt['start']).to_s)

            appt['associatedTravelPayClaim'] = {
              'metadata' => metadata,
              'claim' => cl
            }
            break
          else
            appt['associatedTravelPayClaim'] = {
              'metadata' => metadata
            }
          end
        end
        appointments.push(appt)
      end
      appointments
    end

    def append_error(appts, metadata)
      appointments = []
      appts.each do |appt|
        appt['associatedTravelPayClaim'] = {
          'metadata' => metadata
        }
        appointments.push(appt)
      end
      appointments
    end

    def service
      auth_manager = TravelPay::AuthManager.new(Settings.travel_pay.client_number, @current_user)
      TravelPay::ClaimsService.new(auth_manager)
    end
  end
end
