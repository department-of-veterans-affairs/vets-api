# frozen_string_literal: true

module Eps
  class ProviderService < BaseService
    ##
    # Get provider data from EPS
    #
    # @return OpenStruct response from EPS provider endpoint
    #
    def get_provider_service(provider_id:)
      response = perform(:get, "/#{config.base_path}/provider-services/#{provider_id}",
                         {}, request_headers)

      OpenStruct.new(response.body)
    end

    def get_provider_services_by_ids(provider_ids:)
      query_object_array = provider_ids.map { |id| "id=#{id}" }
      response = perform(:get, "/#{config.base_path}/provider-services",
                         query_object_array, request_headers)

      OpenStruct.new(response.body)
    end

    ##
    # Get networks from EPS
    #
    # @return OpenStruct response from EPS networks endpoint
    #
    def get_networks
      response = perform(:get, "/#{config.base_path}/networks", {}, request_headers)

      OpenStruct.new(response.body)
    end

    ##
    # Get drive times from EPS
    #
    # @param destinations [Hash] Hash of UUIDs mapped to lat/long coordinates
    # @param origin [Hash] Hash containing origin lat/long coordinates
    # @return OpenStruct response from EPS drive times endpoint
    #
    def get_drive_times(destinations:, origin:)
      payload = {
        destinations:,
        origin:
      }

      response = perform(:post, "/#{config.base_path}/drive-times", payload, request_headers)

      OpenStruct.new(response.body)
    end

    ##
    # Retrieves available slots for a specific provider.
    #
    # @param provider_id [String] The unique identifier of the provider
    # @param opts [Hash] Optional parameters for the request
    # @option opts [String] :nextToken Token for pagination of results
    # @option opts [String] :appointmentTypeId Required if nextToken is not provided. The type of appointment
    # @option opts [String] :startOnOrAfter Required if nextToken is not provided. Start of the time range
    #   (ISO 8601 format)
    # @option opts [String] :startBefore Required if nextToken is not provided. End of the time range
    #   (ISO 8601 format)
    # @option opts [Hash] Additional optional parameters will be passed through to the request
    #
    # @raise [ArgumentError] If nextToken is not provided and any of appointmentTypeId, startOnOrAfter, or
    #   startBefore are missing
    #
    # @return [OpenStruct] Response containing available slots
    #
    def get_provider_slots(provider_id, opts = {})
      raise ArgumentError, 'provider_id is required and cannot be blank' if provider_id.blank?

      params = if opts[:nextToken]
                 { nextToken: opts[:nextToken] }
               else
                 required_params = %i[appointmentTypeId startOnOrAfter startBefore]
                 missing_params = required_params - opts.keys

                 raise ArgumentError, "Missing required parameters: #{missing_params.join(', ')}" if missing_params.any?

                 opts
               end

      response = perform(:get, "/#{config.base_path}/provider-services/#{provider_id}/slots", params, request_headers)

      OpenStruct.new(response.body)
    end

    ##
    # Search for provider services using NPI, specialty, and address
    #
    # @param npi [String] NPI number to search for
    # @param specialty [String] Specialty to match (case-insensitive)
    # @param address [Hash] Address object with :street1, :city, :state, :zip keys
    #
    # @return OpenStruct response containing the provider service where an individual provider has
    # matching NPI, specialty, and address, or nil if not found
    #
    def search_provider_services(npi:, specialty:, address:)
      query_params = { npi:, isSelfSchedulable: true }
      response = perform(:get, "/#{config.base_path}/provider-services", query_params, request_headers)

      return nil if response.body[:provider_services].blank?

      # Filter providers by specialty and address
      matching_provider = response.body[:provider_services].find do |provider|
        specialty_matches?(provider, specialty) && address_matches?(provider, address)
      end

      matching_provider&.then { |provider| OpenStruct.new(provider) }
    end

    private

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
        provider_specialty.to_s.casecmp?(specialty.to_s)
      end
    end

    ##
    # Check if provider's address matches the requested address using a two-step approach
    #
    # @param provider [Hash] Provider data from EPS response
    # @param address [Hash] Address object with :street1, :city, :state, :zip keys
    # @return [Boolean] True if address matches, false otherwise
    #
    def address_matches?(provider, address)
      return false if provider.dig(:location, :address).blank? || address.blank?

      provider_address = provider[:location][:address]

      # Step 1: Primary filter - check if street address matches (most likely to filter out non-matches)
      return false unless street_address_matches?(provider_address, address[:street1])

      # Step 2: Full address comparison with logging for monitoring, so we can detect formatting differences
      full_match = full_address_matches?(provider_address, address)

      log_partial_address_match(provider_address, address) unless full_match

      # Return false if full address doesn't match
      full_match
    end

    ##
    # Check if the street portion of provider address matches referral street1
    #
    # @param provider_address [String] Full provider address string
    # @param referral_street1 [String] Street address from referral
    # @return [Boolean] True if street addresses match
    #
    def street_address_matches?(provider_address, referral_street1)
      return false if provider_address.blank? || referral_street1.blank?

      # Check if referral street appears at the beginning of provider address
      normalized_provider_address = normalize_address_text(provider_address)
      normalized_referral_street = normalize_address_text(referral_street1)

      normalized_provider_address.start_with?(normalized_referral_street)
    end

    ##
    # Check if full provider address matches referral address components
    #
    # @param provider_address [String] Full provider address string
    # @param address [Hash] Address object with :street1, :city, :state, :zip keys
    # @return [Boolean] True if full address matches
    #
    def full_address_matches?(provider_address, address)
      # Normalize provider address by removing commas and extra spaces
      normalized_provider = normalize_address_text(provider_address.gsub(',', ' '))

      # Build referral address string, remove commas, and normalize
      address_parts = [
        address[:street1],
        address[:city],
        address[:state],
        address[:zip]
      ].compact.map(&:to_s).compact_blank

      referral_address_string = address_parts.join(' ').gsub(',', ' ')
      normalized_referral = normalize_address_text(referral_address_string)

      normalized_provider == normalized_referral
    end

    ##
    # Log partial match between provider address and referral address
    #
    # @param provider_address [String] Full provider address string
    # @param address [Hash] Address object with :street1, :city, :state, :zip keys
    #
    def log_partial_address_match(provider_address, referral_address)
      return '' if referral_address.blank?

      address_parts = [
        referral_address[:street1],
        referral_address[:city],
        referral_address[:state],
        referral_address[:zip]
      ].compact.map(&:to_s).compact_blank

      if address_parts.any?
        Rails.logger.warn("Provider address partial match detected - Street matched but full address didn't. " \
                          "Provider: '#{provider_address}', " \
                          "Referral: '#{address_parts.join(' ')}'")
      end
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
