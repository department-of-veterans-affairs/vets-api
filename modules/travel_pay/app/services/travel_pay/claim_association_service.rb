# frozen_string_literal: true

module TravelPay
  class ClaimAssociationService
    def initialize(user)
      @user = user
    end
    # We need to associate an existing claim to a VAOS appointment, matching on date-time
    #
    # There will be a 1:1 claimID > appt association
    #
    # Will return a new array:
    #
    # VAOS::Appointment
    #   +  travelPayClaim => {
    #         metadata => {
    #           status => int (http status code, i.e. 200)
    #           success => boolean
    #           message => string ('Data retrieved successfully' | 'Claim service is unavailable')
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
    # appointments: [VAOS::Appointment + travelPayClaim]

    def associate_appointments_to_claims(params = {})
      faraday_response = service.get_claims_by_date_range(
        { 'start_date' => params['start_date'],
          'end_date' => params['end_date'] }
      )

      if faraday_response.status == 200
        append_claims(params['appointments'],
                      faraday_response.body['data'],
                      build_metadata(faraday_response.body))
      else
        append_error(params['appointments'],
                     build_metadata(faraday_response.body))
      end
    end

    def associate_single_appointment_to_claim(params = {})
      appt = params['appointment']

      faraday_response = service.get_claims_by_date_range(
        { 'start_date' => appt['start'],
          'end_date' => appt['start'] }
      )

      appt['travelPayClaim'] = if faraday_response.body['data']&.count
                                 {
                                   'metadata' => build_metadata(faraday_response.body),
                                   'claim' => faraday_response.body['data'][0]
                                 }
                               else
                                 {
                                   'metadata' => build_metadata(faraday_response.body)
                                 }
                               end
      appt
    end

    private

    def append_claims(appts, claims, metadata)
      appointments = []
      appts.each do |appt|
        claims.each do |cl|
          if !cl['appointmentDateTime'].nil? &&
             (DateTime.parse(cl['appointmentDateTime']).to_s == DateTime.parse(appt['start']).to_s)

            appt['travelPayClaim'] = {
              'metadata' => metadata,
              'claim' => cl
            }
            break
          else
            appt['travelPayClaim'] = {
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
        appt['travelPayClaim'] = {
          'metadata' => metadata
        }
        appointments.push(appt)
      end
      appointments
    end

    def build_metadata(faraday_response_body)
      { 'status' => faraday_response_body['statusCode'],
        'success' => faraday_response_body['success'],
        'message' => faraday_response_body['message'] }
    end

    def service
      auth_manager = TravelPay::AuthManager.new(Settings.travel_pay.client_number, @user)
      TravelPay::ClaimsService.new(auth_manager)
    end
  end
end
