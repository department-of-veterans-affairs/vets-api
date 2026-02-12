# frozen_string_literal: true

require 'dependents_benefits/monitor'

module DependentsBenefits
  ##
  # Handles extraction and normalization of user data for dependents benefits claims
  #
  # Combines data from the authenticated user object and claim form data,
  # with user object data taking precedence. Retrieves VA file number from BGS
  # and handles VA Profile email lookup with fallback to form email.
  #
  class UserData
    include DependentsBenefits::DependentsHelper
    attr_reader :first_name,
                :middle_name,
                :last_name,
                :ssn,
                :birth_date,
                :common_name,
                :email,
                :notification_email,
                :icn,
                :participant_id,
                :uuid,
                :va_file_number

    # Initializes UserData with information from user and claim data
    #
    # Extracts user information from the authenticated user object, falling back
    # to claim form data where user data is not available. Retrieves VA file number
    # from BGS and determines the appropriate notification email address.
    #
    # @param user [User] The authenticated user object
    # @param claim_data [Hash] The claim form data containing veteran information
    # @raise [Common::Exceptions::UnprocessableEntity] if initialization fails
    def initialize(user, claim_data)
      @first_name = user.first_name.presence || claim_data.dig('veteran_information', 'full_name', 'first')
      @middle_name = user.middle_name.presence || claim_data.dig('veteran_information', 'full_name', 'middle')
      @last_name = user.last_name.presence || claim_data.dig('veteran_information', 'full_name', 'last')
      @ssn = user.ssn.presence
      @uuid = user.uuid.presence
      @birth_date = user.birth_date.presence || claim_data.dig('veteran_information', 'birth_date')
      @common_name = user.common_name.presence
      @email = user.email.presence || claim_data.dig('veteran_contact_information', 'email_address')
      @icn = user.icn.presence
      @participant_id = user.participant_id.presence
      # Set notification_email from form's email if va_profile_email is not available
      @notification_email = get_user_email(user) || @email
      @va_file_number = get_file_number || ssn
    rescue => e
      monitor.track_error_event('DependentsBenefits::UserData#initialize error',
                                action: 'user_hash.failure', component:, error: e)
      raise Common::Exceptions::UnprocessableEntity.new(detail: 'Could not initialize user data')
    end

    # Generates a JSON representation of the user data
    #
    # Creates a hash containing veteran information with all available user data,
    # removing nil values, and returns it as a JSON string.
    #
    # @return [String] JSON string containing veteran_information hash
    # @raise [Common::Exceptions::UnprocessableEntity] if JSON generation fails
    def get_user_json
      full_name = { 'first' => first_name, 'middle' => middle_name, 'last' => last_name }.compact

      veteran_information = {
        'full_name' => full_name,
        'common_name' => common_name,
        'va_profile_email' => notification_email,
        'email' => email,
        'participant_id' => participant_id,
        'ssn' => ssn,
        'va_file_number' => va_file_number,
        'birth_date' => birth_date,
        'uuid' => uuid,
        'icn' => icn
      }.compact

      { 'veteran_information' => veteran_information }.to_json
    rescue => e
      monitor.track_error_event('DependentsBenefits::UserData#get_user_hash error',
                                action: 'user_hash.failure', component:, error: e)
      raise Common::Exceptions::UnprocessableEntity.new(detail: 'Could not generate user hash')
    end

    private

    # Retrieves the veteran's VA file number from BGS
    #
    # Attempts to find the veteran by participant ID first, then falls back to SSN lookup.
    # Handles file numbers with dashes (XXX-XX-XXXX format) by stripping them out.
    # Returns nil and logs a warning if the lookup fails.
    #
    # @return [String, nil] The VA file number, or nil if lookup fails
    def get_file_number
      return @file_number if @file_number.present?

      begin
        bgs_person = lookup_bgs_person

        # Safely extract file number from BGS response as an instance variable for later use;
        # For more details on why this matters, see dependents_veteran_identifiers.md
        # The short version is that we need the file number to be present for RBPS, but we are retrieving by PID.
        if bgs_person.respond_to?(:[]) && bgs_person[:file_nbr].present?
          @file_number = bgs_person[:file_nbr]
        else
          monitor.track_warning_event('DependentsBenefits::UserData#get_file_number error',
                                      action: 'file_number.missing', component:,
                                      error: 'Missing bgs_person file_nbr',
                                      bgs_person_present: bgs_person.present? ? 'yes' : 'no')
          @file_number = nil
        end

        # Normalize file numbers that are returned in dashed SSN format (XXX-XX-XXXX).
        # BGS's file number is supposed to be an eight or nine-digit string, and
        # our code is built upon the assumption that this is the case. However,
        # we've seen cases where BGS returns a file number with dashes
        # (e.g. XXX-XX-XXXX). In this case specifically, we can simply strip out
        # the dashes and proceed with form submission.
        @file_number = @file_number.delete('-') if @file_number =~ /\A\d{3}-\d{2}-\d{4}\z/

      # This rescue could be hit if BGS is down or unreachable when trying to run find_person_by_ptcpnt_id()
      # It could also be hit if the file number is invalid or missing. We log and continue since we can
      # fall back to using Lighthouse and want to still generate the PDF.
      rescue
        monitor.track_warning_event('DependentsBenefits::UserData#get_file_number error',
                                    action: 'file_number.failure', component:,
                                    error: 'Could not retrieve file number from BGS')
        @file_number = nil
      end

      @file_number
    end

    # Lookup BGS person record by participant_id (preferred) or SSN (fallback)
    def lookup_bgs_person
      bgs_person = service.people.find_person_by_ptcpnt_id(participant_id)
      if bgs_person.present?
        monitor.track_info_event('DependentsBenefits::UserData#get_file_number found bgs_person by PID',
                                 action: 'find_by_participant_id', component:)
      else
        bgs_person = service.people.find_by_ssn(ssn) # rubocop:disable Rails/DynamicFindBy
        monitor.track_info_event('DependentsBenefits::UserData#get_file_number found bgs_person by ssn',
                                 action: 'find_by_ssn', component:)
      end

      bgs_person
    end

    # Returns a memoized BGS service instance
    #
    # @return [BGS::Services] BGS service instance for interacting with BGS API
    def service
      @service ||= BGS::Services.new(external_uid: icn, external_key:)
    end

    # Generates an external key for BGS authentication
    #
    # Uses the common name if available, otherwise falls back to email.
    # Truncates the key to the maximum length allowed by BGS.
    #
    # @return [String] The external key, truncated to BGS max length
    def external_key
      @external_key ||= begin
        key = common_name.presence || email
        key.first(BGS::Constants::EXTERNAL_KEY_MAX_LENGTH)
      end
    end

    # Retrieves the user's VA Profile email address
    #
    # Attempts to get the email from VA Profile. This may fail for:
    # - New users
    # - Users who haven't logged in for over a month
    # - Users who created an account on web
    # - Users who haven't visited their profile page
    # Returns nil and logs a warning if the lookup fails.
    #
    # @param user [User] The authenticated user object
    # @return [String, nil] The VA Profile email address, or nil if lookup fails
    def get_user_email(user)
      # Safeguard for when VAProfileRedis::V2::ContactInformation.for_user fails in app/models/user.rb
      # Failure is expected occasionally due to 404 errors from the redis cache
      # New users, users that have not logged on in over a month, users who created an account on web,
      # and users who have not visited their profile page will need to obtain/refresh VAProfile_ID
      # Originates here: lib/va_profile/contact_information/v2/service.rb
      user.va_profile_email.presence
    rescue => e
      monitor.track_warning_event('DependentsBenefits::UserData#get_user_email failed to get va_profile_email',
                                  action: 'get_va_profile_email.failure', component:, error: e.message)
      nil
    end

    # Returns a memoized instance of the DependentsBenefits monitor
    #
    # @return [DependentsBenefits::Monitor] Monitor instance for tracking events and errors
    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end
  end
end
