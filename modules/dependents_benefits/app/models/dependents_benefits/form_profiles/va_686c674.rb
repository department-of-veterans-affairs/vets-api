# frozen_string_literal: true

require 'vets/model'
require 'bid/awards/service'
require 'dependents_benefits/monitor'

module DependentsBenefits
  ##
  # Form profile for VA Form 686c-674 (Application Request to Add and/or Remove Dependents)
  # Handles prefilling veteran's address and dependent information from BGS and VA Profile services
  # extends app/models/form_profile.rb, which handles form prefill
  class FormProfiles::VA686c674 < FormProfile
    include PensionAwardHelper
    ##
    # Model representing dependent information for the 686c-674 form
    # Contains personal details and relationship data for each dependent
    class DependentInformation
      include Vets::Model

      attribute :full_name, FormFullName
      attribute :date_of_birth, Date
      attribute :ssn, String
      attribute :relationship_to_veteran, String
      attribute :award_indicator, String
    end

    ##
    # Model representing address information for the 686c-674 form
    # Supports both domestic and international addresses
    class FormAddress
      include Vets::Model

      attribute :country_name, String
      attribute :address_line1, String
      attribute :address_line2, String
      attribute :address_line3, String
      attribute :city, String
      attribute :state_code, String
      attribute :province, String
      attribute :zip_code, String
      attribute :international_postal_code, String
    end

    attribute :form_address, FormAddress
    attribute :dependents_information, DependentInformation, array: true

    ##
    # Prefills the form with veteran's address and dependent information
    # Calls individual prefill methods for address and dependents data
    #
    # @return [void]
    def prefill
      prefill_form_address
      prefill_dependents_information

      super
    end

    ##
    # Returns metadata configuration for the form
    #
    # @return [Hash] Form metadata including version, prefill status, and return URL
    def metadata
      {
        version: 0,
        prefill: true,
        returnUrl: '/686-options-selection'
      }
    end

    private

    ##
    # Prefills the veteran's mailing address from VA Profile service
    # Safely handles service failures by rescuing exceptions
    #
    # @return [void]
    def prefill_form_address
      begin
        mailing_address = VAProfileRedis::V2::ContactInformation.for_user(user).mailing_address
      rescue
        nil
      end

      return if mailing_address.blank?

      @form_address = FormAddress.new(
        mailing_address.to_h.slice(
          :address_line1, :address_line2, :address_line3,
          :city, :state_code, :province,
          :zip_code, :international_postal_code
        ).merge(country_name: mailing_address.country_code_iso3)
      )
    end

    ##
    # Retrieves the last four digits of the veteran's file number or SSN
    # Uses BGS service to find person by participant ID
    #
    # @return [String, nil] Last four digits of file number or SSN
    def va_file_number_last_four
      va_file_number&.last(4)
    end

    ##
    # Retrieves and memoizes the veteran's file number from BGS or falls back to SSN
    # Makes BGS API call only once and caches the result for subsequent calls
    #
    # @return [String, nil] The veteran's file number or SSN if file number unavailable
    def va_file_number
      if @va_file_number.nil?
        response = BGS::People::Request.new.find_person_by_participant_id(user:)
        @va_file_number = response&.file_number.presence || user.ssn.presence
      end
      @va_file_number
    rescue => e
      monitor.track_prefill_warning('Failed to retrieve VA file number', 'file_number_error',
                                    error: e&.message)
      user.ssn.presence
    end

    ##
    # This method retrieves the dependents from the BGS service and maps them to the DependentInformation model.
    # If no dependents are found or if they are not active for benefits, it returns an empty array.
    def prefill_dependents_information
      dependents = dependent_service.get_dependents
      persons = if dependents.blank? || dependents[:persons].blank?
                  []
                else
                  dependents[:persons]
                end
      @dependents_information = persons.filter_map do |person|
        person_to_dependent_information(person)
      end
      if Flipper.enabled?(:va_dependents_v3, user)
        @dependents_information = { success: 'true', dependents: @dependents_information }
      else
        @dependents_information
      end
    rescue => e
      monitor.track_prefill_warning('Failed to retrieve dependents information', 'dependents_error',
                                    error: e&.message)
      @dependents_information = Flipper.enabled?(:va_dependents_v3, user) ? { success: 'false', dependents: [] } : []
    end

    ##
    # Assigns a dependent's information to the DependentInformation model.
    #
    # @param person [Hash] The dependent's information as a hash
    # @return [DependentInformation] The dependent's information mapped to the model
    def person_to_dependent_information(person)
      first_name = person[:first_name]
      last_name = person[:last_name]
      middle_name = person[:middle_name]
      ssn = person[:ssn]
      date_of_birth = person[:date_of_birth]
      relationship_to_veteran = person[:relationship]
      award_indicator = person[:award_indicator]

      parsed_date = parse_date_safely(date_of_birth)

      DependentInformation.new(
        full_name: FormFullName.new({
                                      first: first_name,
                                      middle: middle_name,
                                      last: last_name
                                    }),
        date_of_birth: parsed_date,
        ssn:,
        relationship_to_veteran:,
        award_indicator:
      )
    end

    ##
    # Returns a BGS dependent service instance for the current user
    # Memoized to avoid creating multiple instances
    #
    # @return [BGS::DependentService] Service for retrieving dependent information
    def dependent_service
      @dependent_service ||= BGS::DependentService.new(user)
    end

    ##
    # Returns a BID awards service instance for the current user
    # Used to retrieve pension award information
    #
    # @return [BID::Awards::Service] Service for retrieving pension award data
    def pension_award_service
      @pension_award_service ||= BID::Awards::Service.new(user)
    end

    ##
    # Returns a monitoring service instance for tracking events
    # Used for logging errors and tracking form prefill events
    #
    # @return [DependentsBenefits::Monitor] Monitoring service for dependents module
    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end

    ##
    # Implementation of abstract method from PensionAwardHelper
    # Tracks pension award errors using the monitor service
    #
    # @param error [Exception] The error that occurred during pension award retrieval
    def track_pension_award_error(error)
      monitor.track_prefill_warning('Failed to retrieve awards pension data', 'awards_pension_error',
                                    user_account_uuid: user&.user_account_uuid,
                                    error: error.message,
                                    form_id:)
    end

    ##
    # Safely parses a date string, handling various formats
    #
    # @param date_string [String, Date, nil] The date to parse
    # @return [Date, nil] The parsed date or nil if parsing fails
    def parse_date_safely(date_string)
      return nil if date_string.blank?
      return date_string if date_string.is_a?(Date)

      Date.strptime(date_string.to_s, '%m/%d/%Y')
    rescue ArgumentError, TypeError
      nil
    end
  end
end
