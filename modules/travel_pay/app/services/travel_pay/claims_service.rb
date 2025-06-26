# frozen_string_literal: true

module TravelPay
  class ClaimsService
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
          # TODO: Determine if we need these additional metadata fields

          # 'status' => faraday_response.body['statusCode'],
          # 'success' => faraday_response.body['success'],
          # 'message' => faraday_response.body['message'],
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
        page_size: params['page_size'] || DEFAULT_PAGE_SIZE
      }.merge!(date_range)

      @auth_manager.authorize => { veis_token:, btsss_token: }
      all_claims = loop_and_paginate_claims(loop_params, veis_token, btsss_token)

      {
        metadata: {
          # TODO: Determine if we need these additional metadata fields

          # 'status' => faraday_response.body['statusCode'],
          # 'success' => faraday_response.body['success'],
          # 'message' => faraday_response.body['message'],
          # 'pageNumber' => faraday_response.body['pageNumber'],
          # 'pageSize' => faraday_response.body['pageSize'],
          'totalRecordCount' => all_claims[:total_record_count]
        },
        data: all_claims[:data]&.map do |sc|
          sc['claimStatus'] = sc['claimStatus'].underscore.humanize
          sc
        end
      }
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

    # Disabled method length for now due to error handling adding extra lines
    # Once we refactor all Travel Pay services for better error handling we can adjust the length here
    def loop_and_paginate_claims(params, veis_token, btsss_token) # rubocop:disable Metrics/MethodLength
      page_number = 1
      all_claims = []
      total_record_count = 0

      loop do
        client_params = params.merge!({ page_number: })
        faraday_response = client.get_claims_by_date(veis_token, btsss_token, client_params)
        total_record_count = faraday_response.body['totalRecordCount'] unless page_number > 1

        break unless faraday_response.body['statusCode'] == 200

        claims_page = faraday_response.body['data'].deep_dup
        all_claims.concat(claims_page)

        break if all_claims.size >= total_record_count

        page_number += 1
      end

      { data: all_claims, total_record_count: }
    rescue => e
      if all_claims.empty?
        Rails.logger.error(message: "#{e}. Could not retrieve claims by date range.")
        # TODO: replace this with the actual error
        raise Common::Exceptions::BackendServiceException.new(nil, {}, detail: 'Could not retrieve claims.')
      else
        Rails.logger.error(message: "#{e}. Retrieved some claims, page 1 - page #{page_number}.")
        { data: all_claims, total_record_count: }
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
