# frozen_string_literal: true

require 'veteran_status_card/constants'

module VeteranStatusCard
  ##
  # Service class for generating Veteran Status Card data
  # Determines veteran eligibility and returns appropriate card data or error messaging
  #
  class Service
    VET_STATUS_SERVICE_CONFIRMED_TEXT = 'confirmed'
    VET_STATUS_PERSON_NOT_FOUND_TEXT = 'PERSON_NOT_FOUND'
    VET_STATUS_ERROR_TEXT = 'ERROR'
    VET_STATUS_MORE_RESEARCH_REQUIRED_TEXT = 'MORE_RESEARCH_REQUIRED'
    VET_STATUS_NOT_TITLE_38_TEXT = 'NOT_TITLE_38'

    CONFIRMED_SSC_CODES = %w[A1 A2 A3 A4 A5- A1+ A3+ A4+ A3* A4* B1 B2 B3 B4 B5- B1+ B3+ B4+ B5+ B3* B4* B5* G1 G1+ G3+
                             G4+ G5+ R1 R2 R3 R4 R1+ R3+ R4+ R3* R4* D+].freeze

    # Active duty + dishonorable
    DISHONORABLE_SSC_CODES = %w[A5 A5+ A5* B5 G5 G5* R5 R5+ R5*].freeze

    # No active duty + discharge other than dishonorable
    INELIGIBLE_SERVICE_SSC_CODES = %w[G2 G3 G4 G3* G4*].freeze

    UNKNOWN_SERVICE_SSC_CODE = 'U'
    EDIPI_NO_PNL_CODE = 'X'
    CURRENTLY_SERVING_CODES = %w[D D*].freeze
    ERROR_SSC_CODES = %w[VNA DVN DVU CVI].freeze

    ##
    # Initializes the VeteranStatusCard::Service
    #
    # @param user [User] the authenticated user object
    #
    def initialize(user)
      @user = user
    end

    ##
    # Generates the veteran status card data
    # Returns confirmed status with veteran data if eligible, or error details if not
    #
    # @return [Hash] the status card data
    #   - When eligible: { confirmed: true, full_name: String, user_percent_of_disability: Integer,
    #                      latest_service_history: Hash }
    #   - When not eligible: { confirmed: false, title: String, message: String/Array, status: String }
    #
    def status_card
      # Validate required user data
      return error_response_hash(VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE) if @user.nil?

      if eligible?
        {
          confirmed: true,
          full_name:,
          user_percent_of_disability: disability_rating,
          latest_service_history:
        }
      else
        error_details = error_results
        {
          confirmed: false,
          title: error_details[:title],
          message: error_details[:message],
          status: error_details[:status]
        }
      end
    rescue => e
      Rails.logger.error("VeteranStatusCard::Service error: #{e.message}", backtrace: e.backtrace)
      error_response_hash(VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE)
    end

    private

    ##
    # Determines if the veteran is eligible for a status card
    # Checks vet verification status first, then falls back to SSC code eligibility
    #
    # @return [Boolean] true if eligible, false otherwise
    #
    def eligible?
      return true if vet_verification_eligible?

      return true if ssc_eligibile?

      false
    end

    ##
    # Generates error response details based on the reason for ineligibility
    # Returns appropriate messaging based on vet verification status reason or SSC code
    #
    # @return [Hash] error details with keys :confirmed, :title, :message, :status
    #
    def error_results
      # Vet verification status already has title and message for PERSON_NOT_FOUND, ERROR,
      if [VET_STATUS_PERSON_NOT_FOUND_TEXT, VET_STATUS_ERROR_TEXT].include?(vet_verification_status[:reason])
        return {
          title: vet_verification_status[:title],
          message: vet_verification_status[:message],
          status: vet_verification_status[:status]
        }
      end

      # By this point, the remaining reasons are MORE_RESEARCH_REQUIRED and NOT_TITLE_38, so we
      # don't need to explicitly check for those reasons

      return VeteranStatusCard::Constants::DISHONORABLE_RESPONSE if DISHONORABLE_SSC_CODES.include?(ssc_code)

      if INELIGIBLE_SERVICE_SSC_CODES.include?(ssc_code)
        return VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE
      end

      return VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE if ssc_code == UNKNOWN_SERVICE_SSC_CODE

      return VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE if ssc_code == EDIPI_NO_PNL_CODE

      return VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE if CURRENTLY_SERVING_CODES.include?(ssc_code)

      return VeteranStatusCard::Constants::ERROR_RESPONSE if ERROR_SSC_CODES.include?(ssc_code)

      # Default fallback
      VeteranStatusCard::Constants::ERROR_RESPONSE
    end

    ##
    # Returns the user's normalized full name
    #
    # @return [String] the user's full name in normalized format
    #
    def full_name
      @user.full_name_normalized
    end

    ##
    # Gets the user's combined disability rating percentage
    # Uses Lighthouse API if enabled, otherwise falls back to EVSS
    # Returns nil if both services fail
    #
    # @return [Integer, nil] the combined disability rating percentage or nil on error
    #
    def disability_rating
      lighthouse? ? lighthouse_rating : evss_rating
    rescue => e
      Rails.logger.error("Disability rating error: #{e.message}", backtrace: e.backtrace)
      nil
    end

    ##
    # Checks if Lighthouse rating API is enabled for this user
    #
    # @return [Boolean] true if Lighthouse is enabled, false otherwise
    #
    def lighthouse?
      Flipper.enabled?(:profile_lighthouse_rating_info, @user)
    end

    ##
    # Gets the disability rating from Lighthouse API
    # Returns nil if service call fails or user missing ICN
    #
    # @return [Integer, nil] the combined disability rating percentage from Lighthouse or nil on error
    #
    def lighthouse_rating
      return nil if @user.icn.blank?

      lighthouse_disabilities_provider.get_combined_disability_rating
    rescue => e
      Rails.logger.error("Lighthouse disabilities error: #{e.message}", backtrace: e.backtrace)
      nil
    end

    ##
    # Returns the Lighthouse disabilities provider instance (memoized)
    #
    # @return [LighthouseRatedDisabilitiesProvider] the provider instance
    #
    def lighthouse_disabilities_provider
      @lighthouse_disabilities_provider ||= LighthouseRatedDisabilitiesProvider.new(@user.icn)
    end

    ##
    # Gets the disability rating from EVSS API
    # Returns nil if service call fails
    #
    # @return [Integer, nil] the combined disability rating percentage from EVSS or nil on error
    #
    def evss_rating
      return nil if auth_headers.nil?

      evss_service.get_rating_info
    rescue => e
      Rails.logger.error("EVSS rating error: #{e.message}", backtrace: e.backtrace)
      nil
    end

    ##
    # Returns the EVSS service instance (memoized)
    #
    # @return [EVSS::CommonService] the EVSS service instance
    #
    def evss_service
      @evss_service ||= EVSS::CommonService.new(auth_headers)
    end

    ##
    # Builds the authentication headers required for EVSS API calls
    # Returns nil if header generation fails
    #
    # @return [Hash, nil] the combined authentication headers or nil on error
    #
    def auth_headers
      EVSS::DisabilityCompensationAuthHeaders.new(@user).add_headers(EVSS::AuthHeaders.new(@user).to_h)
    rescue => e
      Rails.logger.error("EVSS auth headers error: #{e.message}", backtrace: e.backtrace)
      nil
    end

    ##
    # Gets the user's most recent military service history
    # Returns hash with nil values if service call fails
    #
    # @return [Hash] service history with keys :branch_of_service, :latest_service_date_range
    #   - :branch_of_service [String, nil] the branch of service (e.g., 'Army')
    #   - :latest_service_date_range [Hash, nil] with :begin_date and :end_date
    #
    def latest_service_history
      return { branch_of_service: nil, latest_service_date_range: nil } if @user.edipi.blank?

      response = military_personnel_service.get_service_history

      # Get the most recent service episode (episodes are sorted by begin_date, oldest first)
      last_service = response&.episodes&.last

      {
        branch_of_service: last_service&.branch_of_service,
        latest_service_date_range: format_service_date_range(last_service)
      }
    rescue => e
      Rails.logger.error("VAProfile::MilitaryPersonnel (Service History) error: #{e.message}", backtrace: e.backtrace)
      { branch_of_service: nil, latest_service_date_range: nil }
    end

    ##
    # Formats a service episode's date range into a hash
    #
    # @param service_episode [VAProfile::Models::ServiceHistory, nil] the service episode
    # @return [Hash, nil] date range with :begin_date and :end_date, or nil if no episode
    #
    def format_service_date_range(service_episode)
      return nil unless service_episode

      {
        begin_date: service_episode.begin_date,
        end_date: service_episode.end_date
      }
    end

    ##
    # Determines eligibility based on SSC (Service Summary Code) when vet verification
    # returns MORE_RESEARCH_REQUIRED or NOT_TITLE_38
    #
    # @return [Boolean] true if SSC code indicates eligibility, false otherwise
    #
    def ssc_eligibile?
      return true if more_research_required_not_title_38? && CONFIRMED_SSC_CODES.include?(ssc_code)

      false
    end

    ##
    # Gets the DoD Service Summary Code (memoized)
    #
    # @return [String] the SSC code (e.g., 'A1', 'B2', 'U')
    #
    def ssc_code
      @ssc_code ||= dod_service_summary[:dod_service_summary_code]
    end

    ##
    # Gets the DoD service summary data (memoized)
    # Returns hash with empty strings if response unavailable
    #
    # @return [Hash] service summary with keys :dod_service_summary_code,
    #   :calculation_model_version, :effective_start_date
    #
    def dod_service_summary
      @dod_service_summary ||= begin
        response = military_personnel_response
        if response.nil?
          { dod_service_summary_code: '', calculation_model_version: '', effective_start_date: '' }
        else
          {
            dod_service_summary_code: response.dod_service_summary&.dod_service_summary_code || '',
            calculation_model_version: response.dod_service_summary&.calculation_model_version || '',
            effective_start_date: response.dod_service_summary&.effective_start_date || ''
          }
        end
      end
    end

    ##
    # Gets the military personnel response for DoD service summary (memoized)
    # Returns nil if service call fails or user missing required data
    #
    # @return [VAProfile::MilitaryPersonnel::DodServiceSummaryResponse, nil] the API response or nil on error
    #
    def military_personnel_response
      return @military_personnel_response if defined?(@military_personnel_response)

      @military_personnel_response = begin
        return nil if @user.edipi.blank?

        military_personnel_service.get_dod_service_summary
      rescue => e
        Rails.logger.error("VAProfile::MilitaryPersonnel (DoD Summary) error: #{e.message}", backtrace: e.backtrace)
        nil
      end
    end

    ##
    # Returns the military personnel service instance (memoized)
    #
    # @return [VAProfile::MilitaryPersonnel::Service] the service instance
    #
    def military_personnel_service
      @military_personnel_service ||= VAProfile::MilitaryPersonnel::Service.new(@user)
    end

    ##
    # Checks if the vet verification reason is MORE_RESEARCH_REQUIRED or NOT_TITLE_38
    #
    # @return [Boolean] true if reason matches, false otherwise
    #
    def more_research_required_not_title_38?
      [VET_STATUS_MORE_RESEARCH_REQUIRED_TEXT, VET_STATUS_NOT_TITLE_38_TEXT].include?(vet_verification_status[:reason])
    end

    ##
    # Checks if the veteran is eligible based on vet verification status being 'confirmed'
    #
    # @return [Boolean] true if veteran status is confirmed, false otherwise
    #
    def vet_verification_eligible?
      vet_verification_status[:veteran_status] == VET_STATUS_SERVICE_CONFIRMED_TEXT
    end

    ##
    # Gets the parsed vet verification status data (memoized)
    # Returns hash with nil values if verification response is unavailable
    #
    # @return [Hash] verification status with keys :veteran_status, :reason, :message, :title, :status
    #
    def vet_verification_status
      @vet_verification_status ||= begin
        response = vet_verification_response
        if response.nil?
          {
            veteran_status: nil,
            reason: VET_STATUS_ERROR_TEXT,
            message: VeteranVerification::Constants::ERROR_MESSAGE,
            title: VeteranVerification::Constants::ERROR_MESSAGE_TITLE,
            status: VeteranVerification::Constants::ERROR_MESSAGE_STATUS
          }
        else
          {
            veteran_status: response.dig('data', 'attributes', 'veteran_status'),
            reason: response.dig('data', 'attributes', 'not_confirmed_reason'),
            message: response.dig('data', 'message'),
            title: response.dig('data', 'title'),
            status: response.dig('data', 'status')
          }
        end
      end
    end

    ##
    # Gets the raw vet verification response from the API (memoized)
    # Returns nil if service call fails or user missing required data
    #
    # @return [Hash, nil] the raw API response or nil on error
    #
    def vet_verification_response
      return @vet_verification_response if defined?(@vet_verification_response)

      @vet_verification_response = begin
        return nil if @user.icn.blank?

        vet_verification_service.get_vet_verification_status(@user.icn)
      rescue => e
        Rails.logger.error("VeteranVerification::Service error: #{e.message}", backtrace: e.backtrace)
        nil
      end
    end

    ##
    # Returns the vet verification service instance (memoized)
    #
    # @return [VeteranVerification::Service] the service instance
    #
    def vet_verification_service
      @vet_verification_service ||= VeteranVerification::Service.new
    end

    ##
    # Converts a Constants response to the expected hash format
    #
    # @param response [Hash] the Constants response
    # @return [Hash] formatted error response with :confirmed, :title, :message, :status
    #
    def error_response_hash(response)
      {
        confirmed: false,
        title: response[:title],
        message: response[:message],
        status: response[:status]
      }
    end
  end
end
