# frozen_string_literal: true

module TravelPay
  class ClaimsService
    include ExpenseNormalizer
    include IdValidation

    def initialize(auth_manager, user)
      @auth_manager = auth_manager
      @user = user
    end

    DEFAULT_PAGE_SIZE = 50
    DEFAULT_PAGE_NUMBER = 1

    def get_claims(params)
      @auth_manager.authorize => { veis_token:, btsss_token: }
      faraday_response = client.get_claims(veis_token, btsss_token, {
                                             page_size: params['page_size'] || DEFAULT_PAGE_SIZE,
                                             page_number: params['page_number'] || DEFAULT_PAGE_NUMBER
                                           })
      raw_claims = faraday_response.body['data'].deep_dup

      {
        metadata: {
          'pageNumber' => faraday_response.body['pageNumber'],
          'pageSize' => faraday_response.body['pageSize'],
          'totalRecordCount' => faraday_response.body['totalRecordCount']
        },
        data: raw_claims.map do |sc|
          sc['claimStatus'] = sc['claimStatus'].underscore.humanize
          sc
        end
      }
    end

    def get_claims_by_date_range(params = {})
      date_range = get_date_range(params)

      loop_params = {
        page_size: params['page_size'] || DEFAULT_PAGE_SIZE,
        page_number: params['page_number'] || DEFAULT_PAGE_NUMBER
      }.merge!(date_range)

      @auth_manager.authorize => { veis_token:, btsss_token: }
      start_time = Time.current
      all_claims = loop_and_paginate_claims(loop_params, veis_token, btsss_token)
      elapsed_time = Time.current - start_time
      Rails.logger.info(message: "Looped through #{all_claims[:data].size} claims in #{elapsed_time} seconds.")

      all_claims
    end

    # Retrieves expanded claim details with additional fields
    def get_claim_details(claim_id)
      begin
        validate_uuid_exists!(claim_id, 'Claim')
      rescue Common::Exceptions::BadRequest => e
        raise ArgumentError, e.errors.first.detail
      end

      @auth_manager.authorize => { veis_token:, btsss_token: }
      claim_response = client.get_claim_by_id(veis_token, btsss_token, claim_id)

      documents = get_document_summaries(veis_token, btsss_token, claim_id)

      claim = claim_response.body['data']

      if claim
        claim['claimStatus'] = claim['claimStatus'].underscore.humanize
        claim['documents'] = documents

        # Normalize expense types
        normalize_expenses(claim['expenses']) if claim['expenses']

        # Add decision letter reason for denied or partial payment claims
        add_decision_letter_reason(claim, claim_id) if include_decision_reason?

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

    def include_decision_reason?
      Flipper.enabled?(:travel_pay_claims_management_decision_reason_api, @user)
    end

    def add_decision_letter_reason(claim, claim_id)
      decision_document = find_decision_letter_document(claim)
      return unless (claim['claimStatus'].eql?('Denied') || claim['claimStatus'].casecmp?('Claim paid')) &&
                    !decision_document.nil?

      claim['decision_letter_reason'] = get_decision_reason(claim_id, decision_document['documentId'])
    end

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

    def get_date_range(params)
      # if we get one date, we need both dates
      if params['start_date'] || params['end_date']
        date_range = DateUtils.try_parse_date_range(params['start_date'], params['end_date'])
        date_range = date_range.transform_values { |t| DateUtils.strip_timezone(t).iso8601 }
      else
        # if no dates are provided, default to 3 months ago - today
        date_range = {
          start_date: DateUtils.strip_timezone(3.months.ago).iso8601,
          end_date: DateUtils.strip_timezone(Time.zone.now).iso8601
        }
      end
      date_range
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
        filename.match?(/Decision Letter|Rejection Letter/i) && document['documentId'].present?
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

    def loop_and_paginate_claims(params, veis_token, btsss_token)
      page_number = params[:page_number]
      all_claims = []
      total_record_count = 0

      client_params = params.deep_dup
      faraday_response = client.get_claims_by_date(veis_token, btsss_token, client_params)
      total_record_count = faraday_response.body['totalRecordCount']
      all_claims.concat(faraday_response.body['data'].deep_dup)

      while all_claims.length < total_record_count
        page_number += 1

        client_params[:page_number] = page_number
        faraday_response = client.get_claims_by_date(veis_token, btsss_token, client_params)

        all_claims.concat(faraday_response.body['data'])
      end

      build_claims_response({ data: all_claims, total_record_count:, page_number:, status: 200 })
    rescue => e
      rescue_pagination_errors(e, { data: all_claims, total_record_count:,
                                    page_number: page_number - 1 })
    end

    def build_claims_response(all_claims)
      {
        metadata: {
          'status' => all_claims[:status], # for partial content == 206
          'pageNumber' => all_claims[:page_number], # i.e., we got through page 2, so pick up on page 3
          'totalRecordCount' => all_claims[:total_record_count]
        },
        data: all_claims[:data]&.map do |sc|
          sc['claimStatus'] = sc['claimStatus'].underscore.humanize
          sc
        end
      }
    end

    def rescue_pagination_errors(e, claims)
      if claims[:data].empty?
        Rails.logger.error(message: "#{e}. Could not retrieve claims by date range.")
        # TODO: replace this with the actual error
        raise Common::Exceptions::BackendServiceException.new(nil, {}, detail: 'Could not retrieve claims.')
      else
        claims => { data:, total_record_count:, page_number: }
        Rails.logger.error(message:
        "#{e}. Retrieved #{data.size} of #{total_record_count} claims, ending on page #{page_number}.")
        build_claims_response({ **claims, status: 206 })
      end
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
