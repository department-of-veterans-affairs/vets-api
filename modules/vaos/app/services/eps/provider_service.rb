# frozen_string_literal: true

module Eps
  class ProviderService < BaseService
    ##
    # Get provider data from EPS
    #
    # @return OpenStruct response from EPS provider endpoint
    #
    def get_provider_service(provider_id:)
      with_monitoring do
        response = perform(:get, "/#{config.base_path}/provider-services/#{provider_id}",
                           {}, request_headers_with_correlation_id)

        OpenStruct.new(response.body)
      end
    end

    def get_provider_services_by_ids(provider_ids:)
      with_monitoring do
        query_object_array = provider_ids.map { |id| "id=#{id}" }
        response = perform(:get, "/#{config.base_path}/provider-services",
                           query_object_array, request_headers_with_correlation_id)

        OpenStruct.new(response.body)
      end
    end

    ##
    # Get networks from EPS
    #
    # @return OpenStruct response from EPS networks endpoint
    #
    def get_networks
      with_monitoring do
        response = perform(:get, "/#{config.base_path}/networks", {}, request_headers_with_correlation_id)

        OpenStruct.new(response.body)
      end
    end

    ##
    # Get drive times from EPS
    #
    # @param destinations [Hash] Hash of UUIDs mapped to lat/long coordinates
    # @param origin [Hash] Hash containing origin lat/long coordinates
    # @return OpenStruct response from EPS drive times endpoint
    #
    def get_drive_times(destinations:, origin:)
      with_monitoring do
        payload = {
          destinations:,
          origin:
        }

        response = perform(:post, "/#{config.base_path}/drive-times", payload, request_headers_with_correlation_id)

        OpenStruct.new(response.body)
      end
    end

    ##
    # Retrieves available slots for a specific provider.
    #
    # @param provider_id [String] The unique identifier of the provider
    # @param opts [Hash] Optional parameters for the request
    # @option opts [String] :appointmentTypeId Required. The type of appointment
    # @option opts [String] :startOnOrAfter Required. Start of the time range (ISO 8601 format)
    # @option opts [String] :startBefore Required. End of the time range (ISO 8601 format)
    # @option opts [Hash] Additional optional parameters will be passed through to the request
    #
    # @raise [ArgumentError] If any of appointmentTypeId, startOnOrAfter, or startBefore are missing
    #
    # @return [OpenStruct] Response containing all available slots from all pages
    #
    def get_provider_slots(provider_id, opts = {})
      raise ArgumentError, 'provider_id is required and cannot be blank' if provider_id.blank?

      all_slots = []
      next_token = nil
      start_time = Time.current

      loop do
        check_pagination_timeout(start_time, provider_id)
        params = build_slot_params(next_token, opts)
        response = perform(:get, "/#{config.base_path}/provider-services/#{provider_id}/slots", params,
                           request_headers_with_correlation_id)

        current_response = response.body

        all_slots.concat(current_response[:slots]) if current_response[:slots].present?

        next_token = current_response[:next_token]
        break if next_token.blank?
      end

      combined_response = { slots: all_slots, count: all_slots.length }
      OpenStruct.new(combined_response)
    end

    ##
    # Search for provider services using NPI, specialty and address.
    #
    # @param npi [String] NPI number to search for
    # @param specialty [String] Specialty to match (case-insensitive)
    # @param address [Hash] Address object with :street1, :city, :state, :zip keys
    #
    # @return OpenStruct response containing the provider service where an individual provider has
    # matching NPI, specialty and address.
    #
    def search_provider_services(npi:, specialty:, address:)
      validate_search_params(npi, specialty, address)

      response = fetch_provider_services(npi)
      return nil if response.body[:provider_services].blank?

      specialty_matches = filter_by_specialty(response.body[:provider_services], specialty)
      return nil if specialty_matches.empty?

      return handle_single_specialty_match(specialty_matches) if specialty_matches.size == 1

      find_address_match(specialty_matches, address)
    end

    private

    ##
    # Validates required search parameters
    #
    # @param npi [String] Provider NPI
    # @param specialty [String] Provider specialty
    # @param address [Hash] Provider address
    # @raise [ArgumentError] If any required parameter is blank
    #
    def validate_search_params(npi, specialty, address)
      raise ArgumentError, 'Provider NPI is required and cannot be blank' if npi.blank?
      raise ArgumentError, 'Provider specialty is required and cannot be blank' if specialty.blank?
      raise ArgumentError, 'Provider address is required and cannot be blank' if address.blank?
    end

    ##
    # Fetches provider services from EPS API
    #
    # @param npi [String] Provider NPI
    # @return [Object] Response from EPS API
    #
    def fetch_provider_services(npi)
      with_monitoring do
        query_params = { npi:, isSelfSchedulable: true }
        perform(:get, "/#{config.base_path}/provider-services", query_params,
                request_headers_with_correlation_id)
      end
    end

    ##
    # Filters providers by specialty
    #
    # @param providers [Array] List of providers from EPS response
    # @param specialty [String] Specialty to match
    # @return [Array] Providers matching the specialty
    #
    def filter_by_specialty(providers, specialty)
      providers.select do |provider|
        specialty_matches?(provider, specialty)
      end
    end

    ##
    # Handles the case when only one specialty match is found
    #
    # @param specialty_matches [Array] List of specialty matches
    # @return [OpenStruct] The single provider match
    #
    def handle_single_specialty_match(specialty_matches)
      Rails.logger.info('Single specialty match found for NPI, skipping address validation')
      OpenStruct.new(specialty_matches.first)
    end

    ##
    # Finds provider that matches both specialty and address
    #
    # @param specialty_matches [Array] List of specialty matches
    # @param address [Hash] Address to match against
    # @return [OpenStruct, nil] Provider match or nil if no match found
    #
    def find_address_match(specialty_matches, address)
      address_match = specialty_matches.find do |provider|
        address_matches?(provider, address)
      end

      if address_match.nil?
        warn_data = {
          specialty_matches_count: specialty_matches.size,
          user_uuid: @current_user&.uuid
        }
        message = "#{CC_APPOINTMENTS}: No address match found among #{specialty_matches.size} provider(s) for NPI"
        Rails.logger.warn(message, warn_data)
      end

      address_match&.then { |provider| OpenStruct.new(provider) }
    end

    ##
    # Checks if pagination has exceeded the timeout limit
    #
    # @param start_time [Time] When pagination started
    # @param provider_id [String] Provider identifier for error logging
    # @raise [Common::Exceptions::BackendServiceException] If timeout exceeded
    #
    def check_pagination_timeout(start_time, provider_id)
      timeout_seconds = config.pagination_timeout_seconds
      return unless Time.current - start_time > timeout_seconds

      error_data = {
        provider_id:,
        timeout_seconds:,
        user_uuid: @current_user&.uuid
      }
      Rails.logger.error("#{CC_APPOINTMENTS}: Provider slots pagination timeout", error_data)
      raise Common::Exceptions::BackendServiceException.new(
        'PROVIDER_SLOTS_TIMEOUT',
        source: self.class.to_s
      )
    end

    ##
    # Builds parameters for slot request based on token availability
    #
    # For initial requests (next_token is nil), validates all required parameters including appointmentId.
    # For pagination requests (next_token is present), includes both nextToken and appointmentId.
    # The appointmentId is guaranteed to exist in opts when next_token is present, since next_token
    # only exists after a successful initial request that required appointmentId.
    #
    # @param next_token [String] Token for pagination (only present for subsequent requests)
    # @param opts [Hash] Original request options containing appointmentId and other required params
    # @return [Hash] Parameters for the API request
    #
    def build_slot_params(next_token, opts)
      return { nextToken: next_token, appointmentId: opts[:appointmentId] } if next_token

      required_params = %i[appointmentTypeId startOnOrAfter startBefore appointmentId]
      missing_params = required_params - opts.keys

      raise ArgumentError, "Missing required parameters: #{missing_params.join(', ')}" if missing_params.any?

      opts
    end

    ##
    # Check if provider's specialty matches the requested specialty (case-insensitive)
    #
    # @param provider [Hash] Provider data from EPS response
    # @param specialty [String] Requested specialty to match against
    # @return [Boolean] True if specialty matches, false otherwise
    #
    def specialty_matches?(provider, specialty)
      return false if provider[:specialties].blank? || specialty.blank?

      provider[:specialties].any? do |provider_specialty|
        provider_specialty[:name].to_s.casecmp?(specialty.to_s)
      end
    end

    ##
    # Check if provider's address matches the requested address using simplified matching
    # Compares street address, city, and 5-digit zip code (ignores state to avoid format complexity)
    #
    # @param provider [Hash] Provider data from EPS response
    # @param address [Hash] Address object with :street1, :city, :state, :zip keys
    # @return [Boolean] True if address matches, false otherwise
    #
    def address_matches?(provider, address)
      return false if provider.dig(:location, :address).blank? || address.blank?

      provider_address = provider[:location][:address]

      # Compare the two reliable components: street and 5-digit zip
      street_matches = street_address_matches?(provider_address, address[:street1])
      zip_matches = zip_code_matches?(provider_address, address[:zip])

      # Log for monitoring if some components match but not all (helps identify format issues)
      if zip_matches && !street_matches
        warn_data = {
          street_matches:,
          zip_matches:,
          provider_address:,
          referral_address: "#{address[:street1]}, #{address[:zip]}",
          user_uuid: @current_user&.uuid
        }
        Rails.logger.warn("#{CC_APPOINTMENTS}: Provider address partial match", warn_data)
      end

      street_matches && zip_matches
    end

    ##
    # Check if street address matches by comparing referral street to beginning of provider address
    #
    # @param provider_address [String] Full provider address string
    # @param referral_street [String] Street address from referral
    # @return [Boolean] True if provider address starts with referral street
    #
    def street_address_matches?(provider_address, referral_street)
      return false if provider_address.blank? || referral_street.blank?

      normalized_provider = normalize_address_text(provider_address)
      normalized_referral = normalize_address_text(referral_street)

      normalized_provider.start_with?(normalized_referral)
    end

    ##
    # Check if zip codes match by extracting zip from provider address string
    #
    # @param provider_address [String] Full provider address string
    # @param referral_zip [String] Zip code from referral
    # @return [Boolean] True if 5-digit zip codes match
    #
    def zip_code_matches?(provider_address, referral_zip)
      return false if provider_address.blank? || referral_zip.blank?

      # Extract the LAST 5-digit zip code from provider address string
      # This handles cases where street addresses contain 5-digit numbers (e.g., "16011 NEEDMORE RD")
      # We want the zip code, not the street number
      all_zip_matches = provider_address.scan(/(\d{5})(-\d{4})?/)
      return false if all_zip_matches.empty?

      # Get the last match (should be the actual zip code, not street address number)
      provider_5_digit = all_zip_matches.last[0]

      # Extract 5 digits from referral zip
      referral_5_digit = referral_zip.to_s.gsub(/\D/, '')[0, 5]

      provider_5_digit == referral_5_digit && referral_5_digit.length == 5
    end

    ##
    # Normalize address text by removing extra spaces and converting to lowercase
    #
    # @param text [String] Address text to normalize
    # @return [String] Normalized address text
    #
    def normalize_address_text(text)
      return '' if text.blank?

      text.to_s.strip.downcase.gsub(/\s+/, ' ')
    end

    ##
    # Builds search parameters from the given input parameters.
    #
    # @param params [Hash] A hash containing search filter keys:
    #   - :search_text [String] the text to search for.
    #   - :appointment_id [String] the appointment identifier.
    #   - :npi [String] the National Provider Identifier.
    #   - :network_id [String] the network identifier.
    #   - :max_miles_from_near [Integer] the maximum allowable miles from the specified location.
    #   - :near_location [String] the location reference for proximity.
    #   - :organization_names [Array<String>] an array of organization names.
    #   - :specialty_ids [Array<Integer>] an array of specialty identifiers.
    #   - :visit_modes [Array<String>] an array of visit mode options.
    #   - :include_inactive [Boolean] flag to include inactive records.
    #   - :digital_or_not [Boolean] flag indicating digital capability.
    #   - :is_self_schedulable [Boolean] flag for self-schedulability.
    #   - :next_token [String] token for pagination.
    #
    # @return [Hash] a hash of search parameters with nil values removed.
    def build_search_params(params)
      {
        searchText: params[:search_text],
        appointmentId: params[:appointment_id],
        npi: params[:npi],
        networkId: params[:network_id],
        maxMilesFromNear: params[:max_miles_from_near],
        nearLocation: params[:near_location],
        organizationNames: params[:organization_names],
        specialtyIds: params[:specialty_ids],
        visitModes: params[:visit_modes],
        includeInactive: params[:include_inactive],
        digitalOrNot: params[:digital_or_not],
        isSelfSchedulable: params[:is_self_schedulable],
        nextToken: params[:next_token]
      }.compact
    end
  end
end
