# frozen_string_literal: true

module TravelPay
  class ClaimsService
    def initialize(auth_manager, user)
      @auth_manager = auth_manager
      @user = user
    end

    def get_claims(params = {})
      @auth_manager.authorize => { veis_token:, btsss_token: }
      faraday_response = client.get_claims(veis_token, btsss_token)
      raw_claims = faraday_response.body['data'].deep_dup

      claims = filter_by_date(params['appt_datetime'], raw_claims)

      {
        data: claims.map do |sc|
          sc['claimStatus'] = sc['claimStatus'].underscore.humanize
          sc
        end
      }
    end

    def get_claims_by_date_range(params = {})
      validate_date_params(params['start_date'], params['end_date'])

      @auth_manager.authorize => { veis_token:, btsss_token: }
      faraday_response = client.get_claims_by_date(veis_token, btsss_token, params)

      if faraday_response.body['data']
        raw_claims = faraday_response.body['data'].deep_dup

        {
          metadata: {
            'status' => faraday_response.body['statusCode'],
            'success' => faraday_response.body['success'],
            'message' => faraday_response.body['message']
          },
          data: raw_claims&.map do |sc|
            sc['claimStatus'] = sc['claimStatus'].underscore.humanize
            sc
          end
        }
      end
      # Because we're appending this to the Appointments object, we need to not just throw an exception
      # TODO: Integrate error handling from the token client through every subsequent client/service
    rescue Faraday::Error
      nil
    end

    # Retrieves expanded claim details with additional fields
    def get_claim_details(claim_id)
      # ensure claim ID is the right format, allowing any version
      uuid_all_version_format = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[89ABCD][0-9A-F]{3}-[0-9A-F]{12}$/i

      unless uuid_all_version_format.match?(claim_id)
        raise ArgumentError, message: "Expected claim id to be a valid UUID, got #{claim_id}."
      end

      @auth_manager.authorize => { veis_token:, btsss_token: }
      claim_response = client.get_claim_by_id(veis_token, btsss_token, claim_id)

      documents = get_document_summaries(veis_token, btsss_token, claim_id)

      claim = claim_response.body['data']

      if claim
        claim['claimStatus'] = claim['claimStatus'].underscore.humanize
        claim['documents'] = documents

        # Add decision letter reason for denied or partial payment claims
        decision_document = find_decision_letter_document(claim)
        if (claim['claimStatus'].eql?('Denied') || claim['claimStatus'].eql?('Paid')) && !decision_document.nil?
          claim['decision_letter_reason'] = get_decision_reason(claim_id, decision_document['id'])
        end

        claim
      end
    end

    def create_new_claim(params = {})
      # ensure appt ID is the right format, allowing any version
      uuid_all_version_format = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[89ABCD][0-9A-F]{3}-[0-9A-F]{12}$/i

      unless params['btsss_appt_id']
        raise ArgumentError,
              message: 'You must provide a BTSSS appointment ID to create a claim.'
      end

      unless uuid_all_version_format.match?(params['btsss_appt_id'])
        raise ArgumentError,
              message: "Expected BTSSS appointment id to be a valid UUID, got #{params['btsss_appt_id']}."
      end

      @auth_manager.authorize => { veis_token:, btsss_token: }
      new_claim_response = client.create_claim(veis_token, btsss_token, params)

      new_claim_response.body['data']
    end

    def submit_claim(claim_id)
      unless claim_id
        raise ArgumentError,
              message: 'You must provide a BTSSS claim ID to submit a claim.'
      end

      # ensure claim ID is the right format, allowing any version
      uuid_all_version_format = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[89ABCD][0-9A-F]{3}-[0-9A-F]{12}$/i
      unless uuid_all_version_format.match?(claim_id)
        raise ArgumentError,
              message: 'Expected BTSSS claim id to be a valid UUID'
      end

      @auth_manager.authorize => { veis_token:, btsss_token: }
      submitted_claim_response = client.submit_claim(veis_token, btsss_token, claim_id)

      submitted_claim_response.body['data']
    end

    private

    def filter_by_date(date_string, claims)
      if date_string.present?
        parsed_appt_date = Date.parse(date_string)

        claims.filter do |claim|
          !claim['appointmentDateTime'].nil? &&
            parsed_appt_date == Date.parse(claim['appointmentDateTime'])
        end
      else
        claims
      end
    rescue Date::Error => e
      Rails.logger.warn(message: "#{e}. Not filtering claims by date (given: #{date_string}).")
      claims
    end

    def validate_date_params(start_date, end_date)
      if start_date && end_date
        DateTime.parse(start_date.to_s) && DateTime.parse(end_date.to_s)
      else
        raise ArgumentError,
              message: "Both start and end dates are required, got #{start_date}-#{end_date}."
      end
    rescue Date::Error => e
      Rails.logger.debug(message:
      "#{e}. Invalid date(s) provided (given: #{start_date} & #{end_date}).")
      raise ArgumentError,
            message: "#{e}. Invalid date(s) provided (given: #{start_date} & #{end_date})."
    end

    def get_document_summaries(veis_token, btsss_token, claim_id)
      documents = []
      if include_documents?
        begin
          documents_response = documents_client.get_document_ids(veis_token, btsss_token, claim_id)
          documents = documents_response.body['data'] || []
        rescue => e
          Rails.logger.error(message:
          "#{e}. Could not retrieve document summary for requested claim.")
          # Because we're appending documents to the claim details we need to rescue and return the details,
          # even if we don't get documents
          documents = []
        end
      end
      documents
    end

    def find_decision_letter_document(claim)
      return nil unless claim&.dig('documents')

      claim['documents'].find do |document|
        filename = document['filename'] || ''
        filename.match?(/Decision Letter|Rejection Letter/i)
      end
    end

    def get_decision_reason(claim_id, document_id)
      documents_service = TravelPay::DocumentsService.new(@auth_manager)

      begin
        document_data = documents_service.download_document(claim_id, document_id)
      rescue => e
        Rails.logger.error("Error downloading document for decision reason: #{e.message}")
        return nil
      end

      doc_reader = TravelPay::DocReader.new(document_data[:body])

      # Try to get denial reasons first, then partial payment reasons
      doc_reader.denial_reasons || doc_reader.partial_payment_reasons
    rescue => e
      Rails.logger.error("Error extracting decision reason: #{e.message}")
      nil
    end

    def include_documents?
      Flipper.enabled?(:travel_pay_claims_management, @user)
    end

    def client
      TravelPay::ClaimsClient.new
    end

    def documents_client
      TravelPay::DocumentsClient.new
    end
  end
end
