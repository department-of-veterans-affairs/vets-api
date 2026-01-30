# frozen_string_literal: true

require 'veteran_status_card/constants'

module VeteranStatusCard
  ##
  # Service class for generating Veteran Status Card data
  # Determines veteran eligibility and returns appropriate card data or error messaging
  #
  class Service
    # StatsD suffix constants
    STATSD_TOTAL = 'total'
    STATSD_FAILURE = 'failure'
    STATSD_ELIGIBLE = 'eligible'
    STATSD_INELIGIBLE = 'ineligible'

    # Ineligibility reasons based on logic
    # Used in logging, responses to the frontend, and StatsD suffixes
    DISHONORABLE_SSC_MESSAGE = 'dishonorable_ssc_code'
    INELIGIBLE_SSC_MESSAGE = 'ineligible_ssc_code'
    UNKNOWN_SSC_MESSAGE = 'unknown_ssc_code'
    EDIPI_NO_PNL_SSC_MESSAGE = 'edipi_no_pnl_ssc_code'
    CURRENTLY_SERVING_SSC_MESSAGE = 'currently_serving_ssc_code'
    ERROR_SSC_MESSAGE = 'error_ssc_code'
    UNCAUGHT_SSC_MESSAGE = 'uncaught_ssc_code'
    UNKNOWN_REASON_MESSAGE = 'unknown_reason'

    # Response type constants
    VETERAN_STATUS_CARD = 'veteran_status_card'
    VETERAN_STATUS_ALERT = 'veteran_status_alert'

    # Confirmed status constants
    CONFIRMED_TEXT = 'confirmed'
    NOT_CONFIRMED_TEXT = 'not confirmed'

    # Response constants for vet_verification_status reasons
    VET_STATUS_PERSON_NOT_FOUND_TEXT = 'PERSON_NOT_FOUND'
    VET_STATUS_ERROR_TEXT = 'ERROR'
    VET_STATUS_MORE_RESEARCH_REQUIRED_TEXT = 'MORE_RESEARCH_REQUIRED'
    VET_STATUS_NOT_TITLE_38_TEXT = 'NOT_TITLE_38'

    # Confirmed (eligible) SSC codes
    CONFIRMED_SSC_CODES = %w[A1 A2 A3 A4 A5- A1+ A3+ A4+ A3* A4* B1 B2 B3 B4 B5- B1+ B3+ B4+ B5+ B3* B4* B5* G1 G1+ G3+
                             G4+ G5+ R1 R2 R3 R4 R1+ R3+ R4+ R3* R4* D+].freeze

    # Active duty + dishonorable
    DISHONORABLE_SSC_CODES = %w[A5 A5+ A5* B5 G5 G5* R5 R5+ R5*].freeze

    # No active duty + discharge other than dishonorable
    INELIGIBLE_SERVICE_SSC_CODES = %w[G2 G3 G4 G3* G4*].freeze

    UNKNOWN_SERVICE_SSC_CODE = 'U'
    EDIPI_NO_PNL_CODE = 'X'
    CURRENTLY_SERVING_CODES = %w[D D*].freeze

    # Codes where a real status could not be determined
    ERROR_SSC_CODES = %w[VNA DVN DVU CVI].freeze

    ##
    # Initializes the VeteranStatusCard::Service
    #
    # @param user [User] the authenticated user object
    #
    def initialize(user)
      log_statsd(STATSD_TOTAL)
      @user = user
      @ineligible_message = nil

      if @user.nil?
        log_statsd(STATSD_FAILURE)
        raise ArgumentError, 'User cannot be nil'
      end

      if @user.edipi.blank? || @user.icn.blank?
        log_statsd(STATSD_FAILURE)
        raise ArgumentError, 'User missing required fields'
      end
    end

    ##
    # Generates the veteran status card data
    # Returns confirmed status with veteran data if eligible, or error details if not
    #
    # @return [Hash] the status card data with keys:
    #   - :type [String] 'veteran_status_card' or 'veteran_status_alert'
    #   - :attributes [Hash] containing either:
    #     - When eligible: { full_name:, disability_rating:, latest_service:, edipi:,
    #         confirmation_status:, service_summary_code: }
    #     - When not eligible: { header:, body:, alert_type:, confirmation_status:,
    #         service_summary_code: }
    #
    def status_card
      if eligible?
        log_vsc_result(confirmed: true)

        eligible_response
      else
        error_details = error_results

        log_vsc_result(confirmed: false)

        ineligible_response(error_details)
      end
    rescue => e
      log_statsd(STATSD_FAILURE)
      Rails.logger.error("#{service_name} error: #{e.message}", backtrace: e.backtrace)
      error_response_hash(something_went_wrong_response)
    end

    protected

    ##
    # Returns the StatsD key prefix for metrics
    # Override in subclasses to use a different prefix (e.g., 'veteran_status_card.mobile')
    #
    # @return [String] the StatsD key prefix
    #
    def statsd_key_prefix
      'veteran_status_card'
    end

    ##
    # Returns the service name for logging
    # Override in subclasses to use a different name for log identification
    #
    # @return [String] the service name
    #
    def service_name
      '[VeteranStatusCard::Service]'
    end

    ##
    # Returns the response for unexpected errors
    # Override in subclasses to use different messaging
    #
    # @return [Hash] response with :title, :message, :status keys
    #
    def something_went_wrong_response
      VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE
    end

    ##
    # Returns the response for dishonorable discharge
    # Override in subclasses to use different messaging
    #
    # @return [Hash] response with :title, :message, :status keys
    #
    def dishonorable_response
      VeteranStatusCard::Constants::DISHONORABLE_RESPONSE
    end

    ##
    # Returns the response for ineligible service (no active duty + discharge other than dishonorable)
    # Override in subclasses to use different messaging
    #
    # @return [Hash] response with :title, :message, :status keys
    #
    def ineligible_service_response
      VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE
    end

    ##
    # Returns the response for unknown service history
    # Override in subclasses to use different messaging
    #
    # @return [Hash] response with :title, :message, :status keys
    #
    def unknown_service_response
      VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE
    end

    ##
    # Returns the response when EDIPI has no PNL (Personnel Number List) record
    # Override in subclasses to use different messaging
    #
    # @return [Hash] response with :title, :message, :status keys
    #
    def edipi_no_pnl_response
      VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE
    end

    ##
    # Returns the response for currently serving members
    # Override in subclasses to use different messaging
    #
    # @return [Hash] response with :title, :message, :status keys
    #
    def currently_serving_response
      VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE
    end

    ##
    # Returns the generic error response
    # Override in subclasses to use different messaging
    #
    # @return [Hash] response with :title, :message, :status keys
    #
    def error_response
      VeteranStatusCard::Constants::ERROR_RESPONSE
    end

    private

    ##
    # Logs a StatsD metric with the given key
    #
    # @param key [String] the metric key suffix (e.g., 'total', 'failure', 'eligible', 'ineligible')
    # @return [void]
    #
    def log_statsd(key)
      # Ensure statsd is logged with downcase suffixes
      StatsD.increment("#{statsd_key_prefix}.#{key.downcase}")
    end

    ##
    # Logs the veteran status card result for metrics and debugging
    #
    # @param confirmed [Boolean] whether the status is 'confirmed' or 'not confirmed'
    # @return [void]
    #
    def log_vsc_result(confirmed: false)
      key = confirmed ? STATSD_ELIGIBLE : STATSD_INELIGIBLE
      log_statsd(key)
      log_statsd(ineligible_message_or_vet_verification_reason) unless confirmed
      Rails.logger.info("#{service_name} VSC Card Result", {
                          confirmation_status: confirmation_status(confirmed),
                          service_summary_code: ssc_code
                        })
    end

    ##
    # Retrieves a single string to determine confirmation, or non-confirmation reason
    #
    # @param confirmed [Boolean] whether the status is 'confirmed' (true) or 'not confirmed' (false)
    # @return [String] a single string confirmed status or not confirmed reason
    #
    def confirmation_status(confirmed)
      # If the status is confirmed, use CONFIRMED_TEXT
      # Otherwise, use the message from ineligible_message_or_vet_verification_reason
      (confirmed ? CONFIRMED_TEXT : ineligible_message_or_vet_verification_reason).upcase
    end

    ##
    # Determines a single reason that status is 'not confirmed'
    #
    # @return [String] a single string with the not confirmed reason
    #
    def ineligible_message_or_vet_verification_reason
      # Check for presence on existing reasons to ensure no nil or empty values are passed
      # If both are empty, default to the UNKNOWN_REASON_MESSAGE
      @ineligible_message.presence || vet_verification_status[:reason].presence || UNKNOWN_REASON_MESSAGE
    end

    ##
    # Builds the response for an eligible veteran
    #
    # @return [Hash] the veteran status card response
    #
    def eligible_response
      {
        type: VETERAN_STATUS_CARD,
        attributes: {
          full_name:,
          disability_rating:,
          latest_service: latest_service_history,
          edipi: @user&.edipi,
          confirmation_status: confirmation_status(true),
          service_summary_code: ssc_code
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
        type: VETERAN_STATUS_ALERT,
        attributes: {
          header: error_details[:title],
          body: error_details[:message],
          alert_type: error_details[:status],
          confirmation_status: confirmation_status(false),
          service_summary_code: ssc_code
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
    def response_for_ssc_code # rubocop:disable Metrics/MethodLength
      case ssc_code
      when *DISHONORABLE_SSC_CODES
        @ineligible_message = DISHONORABLE_SSC_MESSAGE
        dishonorable_response
      when *INELIGIBLE_SERVICE_SSC_CODES
        @ineligible_message = INELIGIBLE_SSC_MESSAGE
        ineligible_service_response
      when UNKNOWN_SERVICE_SSC_CODE
        @ineligible_message = UNKNOWN_SSC_MESSAGE
        unknown_service_response
      when EDIPI_NO_PNL_CODE
        @ineligible_message = EDIPI_NO_PNL_SSC_MESSAGE
        edipi_no_pnl_response
      when *CURRENTLY_SERVING_CODES
        @ineligible_message = CURRENTLY_SERVING_SSC_MESSAGE
        currently_serving_response
      when *ERROR_SSC_CODES
        @ineligible_message = ERROR_SSC_MESSAGE
        error_response
      else
        @ineligible_message = UNCAUGHT_SSC_MESSAGE
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
    # Gets the user's most recent military service history
    # Returns hash with nil values if service call fails or no episodes exist
    #
    # @return [Hash] service history with keys:
    #   - :branch [String, nil] the branch of service (e.g., 'Army')
    #   - :begin_date [String, nil] the start of service date
    #   - :end_date [String, nil] the end of service date
    #
    def latest_service_history
      return @latest_service_history if defined?(@latest_service_history)

      # Get the most recent service episode (episodes are sorted by begin_date, oldest first)
      last_service = service_history_response&.episodes&.last
      if last_service.nil?
        @latest_service_history = { branch: nil, begin_date: nil, end_date: nil }
        return @latest_service_history
      end

      last_service_dates = format_service_date_range(last_service)

      @latest_service_history = {
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
      vet_verification_status[:veteran_status] == CONFIRMED_TEXT
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
    # @return [Hash] formatted error response with :type, :veteran_status, :service_summary_code,
    #    :not_confirmed_reason, :attributes
    #
    def error_response_hash(response)
      {
        type: VETERAN_STATUS_ALERT,
        attributes: {
          header: response[:title],
          body: response[:message],
          alert_type: response[:status],
          confirmation_status: confirmation_status(false),
          service_summary_code: ssc_code
        }
      }
    end
  end
end
