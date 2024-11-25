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
      validate_date_params(params['start_date'], params['end_date'])

      auth_manager.authorize => { veis_token:, btsss_token: }
      faraday_response = client.get_claims_by_date(veis_token, btsss_token,
                                                   { 'start_date' => params['start_date'],
                                                     'end_date' => params['end_date'] })

      if faraday_response.status == 200
        raw_claims = faraday_response.body['data'].deep_dup

        data = raw_claims&.map do |sc|
          sc['claimStatus'] = sc['claimStatus'].underscore.titleize
          sc
        end

        append_claims(params['appointments'],
                      data,
                      build_metadata(faraday_response.body))

      end
    rescue => e
      append_error(params['appointments'],
                   rescue_errors(e))
    end

    def associate_single_appointment_to_claim(params = {})
      appt = params['appointment']
      # Because we only receive a single date/time but the external endpoint requires 2 dates
      # in this case both start and end dates are the same

      validate_date_params(appt['start'], appt['start'])

      auth_manager.authorize => { veis_token:, btsss_token: }
      faraday_response = client.get_claims_by_date(veis_token, btsss_token,
                                                   { 'start_date' => appt['start'], 'end_date' => appt['start'] })

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
    rescue => e
      appt['travelPayClaim'] = {
        'metadata' => rescue_errors(e)
      }
      appt
    end

    private

    def rescue_errors(e) # rubocop:disable Metrics/MethodLength
      if e.is_a?(ArgumentError)
        Rails.logger.error(message: e.message.to_s)
        {
          'status' => 400,
          'message' => e.message.to_s,
          'success' => false
        }
      elsif e.is_a?(Common::Exceptions::BackendServiceException)
        Rails.logger.error(message: "#{e}, #{e.original_body}")
        {
          'status' => e.original_status,
          'message' => e.original_body['message'],
          'success' => false
        }
      else
        Rails.logger.error(message: "An unknown error occured: #{e}")
        {
          'status' => 520, # Unknown error code
          'message' => "An unknown error occured: #{e}",
          'success' => false
        }
      end
    end

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

    def validate_date_params(start_date, end_date)
      if start_date && end_date
        DateTime.parse(start_date.to_s) && DateTime.parse(end_date.to_s)
      else
        raise ArgumentError,
              message: "Both start and end dates are required, got #{start_date}-#{end_date}."
      end
    rescue Date::Error => e
      raise ArgumentError,
            message: "#{e}. Invalid date(s) provided (given: #{start_date} & #{end_date})."
    end

    def auth_manager
      @auth_manager ||= TravelPay::AuthManager.new(Settings.travel_pay.client_number, @user)
    end

    def client
      TravelPay::ClaimsClient.new
    end
  end
end
