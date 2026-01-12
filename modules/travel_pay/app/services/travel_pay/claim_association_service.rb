# frozen_string_literal: true

module TravelPay
  class ClaimAssociationService
    def initialize(user, client)
      @user = user
      @client = client
    end

    DEFAULT_PAGE_SIZE = 50

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

    # Fetches claims by date range and returns claims data and metadata
    # This method can be used for parallel execution
    #
    # @param start_date [String] start date for the query
    # @param end_date [String] end date for the query
    # @return [Hash] hash with :claims (array), :metadata (hash), and :error (boolean) keys
    def fetch_claims_by_date(start_date, end_date)
      client_params = build_claims_request_params(start_date, end_date)
      auth_manager.authorize => { veis_token:, btsss_token: }
      faraday_response = client.get_claims_by_date(veis_token, btsss_token, client_params)

      process_claims_response(faraday_response)
    rescue => e
      { claims: [], metadata: rescue_errors(e), error: true }
    end

    def associate_appointments_to_claims(params = {})
      result = fetch_claims_by_date(params['start_date'], params['end_date'])

      if result[:error]
        append_error(params['appointments'], result[:metadata])
      else
        append_claims(params['appointments'], result[:claims], result[:metadata])
      end
    end

    def build_claims_request_params(start_date, end_date)
      date_range = DateUtils.try_parse_date_range(start_date, end_date)
      date_range = date_range.transform_values { |t| DateUtils.strip_timezone(t).iso8601 }
      { page_size: DEFAULT_PAGE_SIZE }.merge!(date_range)
    end

    def process_claims_response(faraday_response)
      metadata = build_metadata(faraday_response.body)

      if faraday_response.status == 200
        raw_claims = faraday_response.body['data'].deep_dup
        data = format_claims_data(raw_claims)
        { claims: data, metadata:, error: false }
      else
        { claims: [], metadata:, error: true }
      end
    end

    def format_claims_data(raw_claims)
      raw_claims&.map do |sc|
        sc['claimStatus'] = sc['claimStatus'].underscore.humanize
        sc
      end
    end

    def associate_single_appointment_to_claim(params = {})
      appt = params['appointment']
      # Because we only receive a single date/time but the external endpoint requires 2 dates
      # in this case both start and end dates are the same
      date_range = DateUtils.try_parse_date_range(appt[:local_start_time], appt[:local_start_time])
      date_range = date_range.transform_values { |t| DateUtils.strip_timezone(t).iso8601 }

      auth_manager.authorize => { veis_token:, btsss_token: }
      faraday_response = client.get_claims_by_date(veis_token, btsss_token, date_range)

      claim_data = faraday_response.body['data']&.dig(0)

      claim_data['claimStatus'] = claim_data['claimStatus'].underscore.humanize if claim_data

      appt['travelPayClaim'] = {}
      appt['travelPayClaim']['metadata'] = build_metadata(faraday_response.body)
      appt['travelPayClaim']['claim'] = claim_data if claim_data

      appt
    rescue => e
      appt['travelPayClaim'] = {
        'metadata' => rescue_errors(e)
      }
      appt
    end

    private

    def rescue_errors(e) # rubocop:disable Metrics/MethodLength
      if e.is_a?(ArgumentError) || e.is_a?(InvalidComparableError)
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
      appts.reduce([]) do |acc, appt|
        appt['travelPayClaim'] = {
          'metadata' => metadata
        }

        begin
          # The local_start_time on an appointment may not be valid for certain cases
          if DateUtils.valid_datetime? appt[:local_start_time]
            matching_claim = find_matching_claim(claims, appt[:local_start_time])
            appt['travelPayClaim']['claim'] = matching_claim if matching_claim.present?
          else
            Rails.logger.warn(message: "Invalid local_start_time given: #{appt[:local_start_time]}")
            build_invalid_appt_date_response(appt)
          end
        rescue InvalidComparableError => e
          Rails.logger.warn(message: "Cannot compare start times. #{e.message}")
        end

        acc.push(appt)
      end
    end

    def build_invalid_appt_date_response(appt)
      appt['travelPayClaim']['metadata'] = {
        'success' => false,
        'status' => 500,
        'message' => 'local_start_time cannot be parsed'
      }

      appt['travelPayClaim']['claim'] = nil

      appt
    end

    def find_matching_claim(claims, appt_start)
      ClaimMatcher.find_matching_claim(claims, appt_start)
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

    def auth_manager
      @client_number = if @client == 'mobile'
                         Settings.travel_pay.mobile_client_number
                       else
                         # default to the VA.gov client number
                         Settings.travel_pay.client_number
                       end
      @auth_manager ||= TravelPay::AuthManager.new(@client_number, @user)
    end

    def client
      TravelPay::ClaimsClient.new
    end
  end
end
