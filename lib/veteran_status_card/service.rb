# frozen_string_literal: true

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

    CONFIRMED_SSC_CODES = %w[A1 A2 B1 B2 R1 R2 G1 G2].freeze
    TBD_SSC_CODES = %w[A3 A4 A5- B3 B4 B5- R3 R4].freeze # TODO: Unsure of what to do with these codes yet
    DISHONORABLE_SSC_CODES = %w[A5 B5 G3 G4 G5 R5].freeze # TODO: Unsure of what the messaging is for these
    UNKNOWN_SERVICE_SSC_CODE = 'U'
    EDIPI_NO_PNL_CODE = 'X'
    CURRENTLY_SERVING_CODE = 'D^'
    ERROR_SSC_CODES = %w[VNA DVN].freeze

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
          confirmed: false,
          title: vet_verification_status[:title],
          message: vet_verification_status[:message],
          status: vet_verification_status[:status]
        }
      end

      # By this point, the remaining reasons are MORE_RESEARCH_REQUIRED and NOT_TITLE_38, so we
      # don't need to explicitly check for those reasons

      error_response = {
        confirmed: false,
        title: VeteranVerification::Constants::ERROR_MESSAGE_TITLE,
        message: VeteranVerification::Constants::ERROR_MESSAGE,
        status: VeteranVerification::Constants::ERROR_MESSAGE_STATUS
      }

      if TBD_SSC_CODES.include?(ssc_code)
        # Unsure of how to handle these codes yet
        return error_response
      end

      if DISHONORABLE_SSC_CODES.include?(ssc_code)
        # Unsure of what the messaging is for these
        return error_response
      end

      if ssc_code == UNKNOWN_SERVICE_SSC_CODE
        # Unsure of what the messaging is for these
        return error_response
      end

      if ssc_code == EDIPI_NO_PNL_CODE
        # Unsure of what the messaging is for these
        return error_response
      end

      if ssc_code == CURRENTLY_SERVING_CODE
        # Unsure of what the messaging is for these
        return error_response
      end

      if ERROR_SSC_CODES.include?(ssc_code)
        # Unsure of what the messaging is for these
        return error_response
      end

      # Default fallback
      error_response
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
    #
    # @return [Integer] the combined disability rating percentage
    #
    def disability_rating
      lighthouse? ? lighthouse_rating : evss_rating
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
    #
    # @return [Integer] the combined disability rating percentage from Lighthouse
    #
    def lighthouse_rating
      lighthouse_disabilities_provider.get_combined_disability_rating
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
    #
    # @return [Integer] the combined disability rating percentage from EVSS
    #
    def evss_rating
      evss_service.get_rating_info
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
    #
    # @return [Hash] the combined authentication headers
    #
    def auth_headers
      EVSS::DisabilityCompensationAuthHeaders.new(@user).add_headers(EVSS::AuthHeaders.new(@user).to_h)
    end

    ##
    # Gets the user's most recent military service history
    #
    # @return [Hash] service history with keys :branch_of_service, :latest_service_date_range
    #   - :branch_of_service [String, nil] the branch of service (e.g., 'Army')
    #   - :latest_service_date_range [Hash, nil] with :begin_date and :end_date
    #
    def latest_service_history
      response = military_personnel_service.get_service_history

      # Get the most recent service episode (episodes are sorted by begin_date, oldest first)
      last_service = response.episodes.last

      {
        branch_of_service: last_service&.branch_of_service,
        latest_service_date_range: format_service_date_range(last_service)
      }
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
    #
    # @return [Hash] service summary with keys :dod_service_summary_code,
    #   :calculation_model_version, :effective_start_date
    #
    def dod_service_summary
      @dod_service_summary ||= {
        dod_service_summary_code: military_personnel_response.dod_service_summary&.dod_service_summary_code || '',
        calculation_model_version: military_personnel_response.dod_service_summary&.calculation_model_version || '',
        effective_start_date: military_personnel_response.dod_service_summary&.effective_start_date || ''
      }
    end

    ##
    # Gets the military personnel response for DoD service summary (memoized)
    #
    # @return [VAProfile::MilitaryPersonnel::DodServiceSummaryResponse] the API response
    #
    def military_personnel_response
      @military_personnel_response ||= military_personnel_service.get_dod_service_summary
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
    #
    # @return [Hash] verification status with keys :veteran_status, :reason, :message, :title, :status
    #
    def vet_verification_status
      @vet_verification_status ||= {
        veteran_status: vet_verification_response.dig('data', 'attributes', 'veteran_status'),
        reason: vet_verification_response.dig('data', 'attributes', 'not_confirmed_reason'),
        message: vet_verification_response.dig('data', 'message'),
        title: vet_verification_response.dig('data', 'title'),
        status: vet_verification_response.dig('data', 'status')
      }
    end

    ##
    # Gets the raw vet verification response from the API (memoized)
    #
    # @return [Hash] the raw API response
    #
    def vet_verification_response
      @vet_verification_response ||= vet_verification_service.get_vet_verification_status(@user.icn)
    end

    ##
    # Returns the vet verification service instance (memoized)
    #
    # @return [VeteranVerification::Service] the service instance
    #
    def vet_verification_service
      @vet_verification_service ||= VeteranVerification::Service.new
    end
  end
end
