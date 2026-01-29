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

      raise ArgumentError, 'User cannot be nil' if @user.nil?
      raise ArgumentError, 'User missing required fields' if @user.edipi.blank? || @user.icn.blank?
    end

    ##
    # Generates the veteran status card data
    # Returns confirmed status with veteran data if eligible, or error details if not
    #
    # @return [Hash] the status card data with keys:
    #   - :type [String] 'veteran_status_card' or 'veteran_status_alert'
    #   - :veteran_status [String] 'confirmed' or 'not confirmed'
    #   - :service_summary_code [String, nil] the DoD service summary code
    #   - :not_confirmed_reason [String, nil] reason for ineligibility
    #   - :attributes [Hash] containing either:
    #     - When eligible: { full_name:, disability_rating:, latest_service:, edipi: }
    #     - When not eligible: { header:, body:, alert_type: }
    #
    def status_card
      # Validate required user data
      if eligible?
        # Check if service history exists before returning eligible response
        return error_response_hash(unknown_service_response) unless service_history?

        eligible_response
      else
        error_details = error_results
        ineligible_response(error_details)
      end
    rescue => e
      Rails.logger.error("VeteranStatusCard::Service error: #{e.message}", backtrace: e.backtrace)
      error_response_hash(something_went_wrong_response)
    end

    protected

    def something_went_wrong_response
      VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE
    end

    def dishonorable_response
      VeteranStatusCard::Constants::DISHONORABLE_RESPONSE
    end

    def ineligible_service_response
      VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE
    end

    def unknown_service_response
      VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE
    end

    def edipi_no_pnl_response
      VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE
    end

    def currently_serving_response
      VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE
    end

    def error_response
      VeteranStatusCard::Constants::ERROR_RESPONSE
    end

    private

    ##
    # Builds the response for an eligible veteran
    #
    # @return [Hash] the veteran status card response
    #
    def eligible_response
      {
        type: 'veteran_status_card',
        veteran_status: 'confirmed',
        service_summary_code: ssc_code,
        not_confirmed_reason: vet_verification_status[:reason],
        attributes: {
          full_name:,
          disability_rating:,
          latest_service: latest_service_history,
          edipi: @user&.edipi
        }
      }
    end

    ##
    # Builds the response for an ineligible veteran
    #
    # @param error_details [Hash] the error details from error_results
    # @return [Hash] the veteran status alert response
    #
    def ineligible_response(error_details)
      {
        type: 'veteran_status_alert',
        veteran_status: 'not confirmed',
        service_summary_code: ssc_code,
        not_confirmed_reason: vet_verification_status[:reason],
        attributes: {
          header: error_details[:title],
          body: error_details[:message],
          alert_type: error_details[:status]
        }
      }
    end

    ##
    # Builds the error response when user is nil
    # Does not attempt to access user data
    #
    # @return [Hash] the error response
    #
    def nil_user_error_response
      alert_response = something_went_wrong_response
      {
        type: 'veteran_status_alert',
        veteran_status: 'not confirmed',
        service_summary_code: nil,
        not_confirmed_reason: nil,
        attributes: {
          header: alert_response[:title],
          body: alert_response[:message],
          alert_type: alert_response[:status]
        }
      }
    end

    ##
    # Determines if the veteran is eligible for a status card
    # Checks vet verification status first, then falls back to SSC code eligibility
    #
    # @return [Boolean] true if eligible, false otherwise
    #
    def eligible?
      vet_verification_eligible? || ssc_eligible?
    end

    ##
    # Generates error response details based on the reason for ineligibility
    # Returns appropriate messaging based on vet verification status reason or SSC code
    #
    # @return [Hash] error details with keys :title, :message, :status
    #
    def error_results
      # Vet verification status already has title and message for PERSON_NOT_FOUND, ERROR
      if [VET_STATUS_PERSON_NOT_FOUND_TEXT, VET_STATUS_ERROR_TEXT].include?(vet_verification_status[:reason])
        return {
          title: vet_verification_status[:title],
          message: vet_verification_status[:message],
          status: vet_verification_status[:status]
        }
      end

      # By this point, the remaining reasons are MORE_RESEARCH_REQUIRED and NOT_TITLE_38
      response_for_ssc_code
    end

    ##
    # Returns the appropriate error response based on the SSC (Service Summary Code)
    # Maps specific SSC codes to their corresponding error responses
    #
    # @return [Hash] error response with keys :title, :message, :status
    #
    def response_for_ssc_code
      case ssc_code
      when *DISHONORABLE_SSC_CODES
        dishonorable_response
      when *INELIGIBLE_SERVICE_SSC_CODES
        ineligible_service_response
      when UNKNOWN_SERVICE_SSC_CODE
        unknown_service_response
      when EDIPI_NO_PNL_CODE
        edipi_no_pnl_response
      when *CURRENTLY_SERVING_CODES
        currently_serving_response
      when *ERROR_SSC_CODES
        error_response
      else # rubocop:disable Lint/DuplicateBranch
        # Rubocop would catch this as a duplicate branch, but we want to explicitly
        # keep the ERROR_SSC_CODES branch for documentation and in case the response changes
        error_response
      end
    end

    ##
    # Returns the user's formatted full name as a string
    # Capitalizes any single-letter words (initials) in the middle name
    #
    # @return [String] the user's full name formatted as "First Middle Last Suffix"
    #
    def full_name
      name = @user.full_name_normalized
      first = name[:first] || ''
      middle = name[:middle] || ''
      last = name[:last] || ''
      suffix = name[:suffix] || ''

      # Capitalize any single-letter words (initials) in the middle name
      formatted_middle = middle.present? ? middle.gsub(/\b\w\b/, &:upcase) : ''

      [first, formatted_middle, last, suffix].compact_blank.join(' ')
    end

    ##
    # Gets the disability rating from Lighthouse API
    # Returns nil if service call fails or user missing ICN
    #
    # @return [Integer, nil] the combined disability rating percentage from Lighthouse or nil on error
    #
    def disability_rating
      lighthouse_disabilities_provider.get_combined_disability_rating
    rescue => e
      Rails.logger.error("Disability rating error: #{e.message}", backtrace: e.backtrace)
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
    # Checks if the user has any service history episodes
    #
    # @return [Boolean] true if service history episodes exist, false otherwise
    #
    def service_history?
      service_history_response&.episodes&.any?
    end

    ##
    # Gets the user's most recent military service history
    # Returns hash with nil values if service call fails or no episodes exist
    #
    # @return [Hash] service history with keys:
    #   - :branch [String, nil] the branch of service (e.g., 'Army')
    #   - :begin_date [String, nil] the start of service date
    #   - :end_date [String, nil] the end of service date
    #
    def latest_service_history
      # Get the most recent service episode (episodes are sorted by begin_date, oldest first)
      last_service = service_history_response&.episodes&.last
      return { branch: nil, begin_date: nil, end_date: nil } if last_service.nil?

      last_service_dates = format_service_date_range(last_service)

      {
        branch: last_service.branch_of_service,
        begin_date: last_service_dates&.dig(:begin_date),
        end_date: last_service_dates&.dig(:end_date)
      }
    end

    ##
    # Gets the service history response (memoized)
    # Returns nil if service call fails or user missing EDIPI
    #
    # @return [VAProfile::MilitaryPersonnel::ServiceHistoryResponse, nil] the API response or nil on error
    #
    def service_history_response
      return @service_history_response if defined?(@service_history_response)
      return @service_history_response = nil if @user.edipi.blank?

      @service_history_response = begin
        military_personnel_service.get_service_history
      rescue => e
        Rails.logger.error("VAProfile::MilitaryPersonnel (Service History) error: #{e.message}",
                           backtrace: e.backtrace)
        nil
      end
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
    def ssc_eligible?
      more_research_required_not_title_38? && CONFIRMED_SSC_CODES.include?(ssc_code)
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
      return @military_personnel_response = nil if @user.edipi.blank?

      @military_personnel_response = begin
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
            message: error_response[:message],
            title: error_response[:title],
            status: error_response[:status]
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
      return @vet_verification_response = nil if @user.icn.blank?

      @vet_verification_response = begin
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
        type: 'veteran_status_alert',
        veteran_status: 'not confirmed',
        service_summary_code: ssc_code,
        not_confirmed_reason: vet_verification_status[:reason],
        attributes: {
          header: response[:title],
          body: response[:message],
          alert_type: response[:status]
        }
      }
    end
  end
end
