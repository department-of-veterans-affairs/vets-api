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
    STATSD_SUCCESS = 'success'

    # Messages for user's missing fields
    NO_ICN_MESSAGE = 'ineligible_no_icn'
    NO_EDIPI_MESSAGE = 'ineligible_no_edipi'

    # Default value in case SSC codes are never checked
    ELIGIBLE_NO_SSC_CHECK_MESSAGE = 'eligible_no_ssc_check'
    INELIGIBLE_NO_SSC_CHECK_MESSAGE = 'ineligible_no_ssc_check'

    # Ineligibility reasons based on logic
    # Used in logging, responses to the frontend, and StatsD suffixes
    DISHONORABLE_SSC_MESSAGE = 'ineligible_dishonorable_ssc'
    INELIGIBLE_SERVICE_SSC_MESSAGE = 'ineligible_service_ssc'
    UNKNOWN_SSC_MESSAGE = 'ineligible_unknown_ssc'
    EDIPI_NO_PNL_SSC_MESSAGE = 'ineligible_edipi_no_pnl_ssc'
    CURRENTLY_SERVING_SSC_MESSAGE = 'ineligible_currently_serving_ssc'
    ERROR_SSC_MESSAGE = 'ineligible_error_ssc'
    UNCAUGHT_SSC_MESSAGE = 'ineligible_uncaught_ssc'

    # Confirmed SSC messages
    AD_DSCH_VAL_SSC_MESSAGE = 'eligible_ad_dsch_val_ssc'
    AD_VAL_PREV_QUAL_SSC_MESSAGE = 'eligible_ad_val_prev_qual_ssc'
    AD_VAL_PREV_RES_GRD_SSC_MESSAGE = 'eligible_ad_val_prev_res_grd_ssc'
    AD_UNCHAR_DSCH_SSC_MESSAGE = 'eligible_ad_unchar_dsch_ssc'
    VAL_PREV_QUAL_SSC_MESSAGE = 'eligible_val_prev_qual_ssc'

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
    AD_DSCH_VAL_SSC_CODES = %w[A1 A3 A4 A5- B1 B3 B4 B5- R1 R3 R4].freeze
    AD_VAL_PREV_QUAL_SSC_CODES = %w[A1+ A3+ A4+ B1+ B3+ B4+ B5+ R1+ R3+ R4+].freeze
    AD_VAL_PREV_RES_GRD_SSC_CODES = %w[A3* A4* B3* B4* B5* R3* R4*].freeze
    AD_UNCHAR_DSCH_SSC_CODES = %w[A2 B2 R2].freeze
    VAL_PREV_QUAL_SSC = %w[G1 G1+ G3+ G4+ G5+ D+].freeze

    # Active duty + dishonorable
    DISHONORABLE_SSC_CODES = %w[A5 A5+ A5* B5 G5 G5* R5 R5+ R5*].freeze

    # No active duty + discharge other than dishonorable
    INELIGIBLE_SERVICE_SSC_CODES = %w[G2 G3 G4 G3* G4*].freeze

    UNKNOWN_SERVICE_SSC_CODE = 'U'
    EDIPI_NO_PNL_CODE = 'X'
    CURRENTLY_SERVING_CODES = %w[D D*].freeze

    # Codes where a real status could not be determined
    ERROR_SSC_CODES = %w[VNA DVN DVU CVI].freeze

    # Message codes to signify what message the end user is seeing for logging purposes
    CONFIRMED_MESSAGE = 'status_card_confirmed'
    SOMETHING_WENT_WRONG_MESSAGE = 'something_went_wrong'
    DISHONORABLE_MESSAGE = 'dishonorable'
    INELIGIBLE_SERVICE_MESSAGE = 'ineligible_service'
    UNKNOWN_ELIGIBILITY_MESSAGE = 'unknown_eligibility'
    CURRENTLY_SERVING_MESSAGE = 'currently_serving'
    UNCAUGHT_ERROR_MESSAGE = 'uncaught_error'
    PERSON_NOT_FOUND_MESSAGE = 'person_not_found'

    ##
    # Initializes the VeteranStatusCard::Service
    #
    # @param user [User] the authenticated user object
    #
    def initialize(user)
      log_statsd(STATSD_TOTAL)
      @user = user
      @confirmation_status = INELIGIBLE_NO_SSC_CHECK_MESSAGE
      @user_message = nil
    end

    ##
    # Generates the veteran status card data
    # Returns confirmed status with veteran data if eligible, or error details if not
    #
    # @return [Hash] the status card data with keys:
    #   - :type [String] 'veteran_status_card' or 'veteran_status_alert'
    #   - :attributes [Hash] containing either:
    #     - When eligible: { full_name:, disability_rating:, edipi:,
    #         veteran_status:, not_confirmed_reason:, confirmation_status:, service_summary_code: }
    #     - When not eligible: { header:, body:, alert_type:, veteran_status:,
    #         not_confirmed_reason:, confirmation_status:, service_summary_code: }
    #
    def status_card # rubocop:disable Metrics/MethodLength
      # Check up front that the ICN is present, as this is required for the VetVerificationStatus service
      if @user&.icn.blank?
        @confirmation_status = NO_ICN_MESSAGE
        log_missing_fields
        return person_not_found_response_hash
      end

      # Fire VetVerification and DoD Summary in parallel. DoD Summary requires EDIPI,
      # so only start that thread when it is present.
      prefetch_service_data

      # If the ICN is present, check if the VetVerificationStatus is confirmed first
      if vet_verification_eligible?
        @confirmation_status = ELIGIBLE_NO_SSC_CHECK_MESSAGE
        log_vsc_result(confirmed: true)
        return eligible_response
      end

      # If the VetVerificationStatus is not confirmed, check that EDIPI is present as this
      # is required for the VAProfile request
      if @user&.edipi.blank?
        @confirmation_status = NO_EDIPI_MESSAGE
        log_missing_fields
        return person_not_found_response_hash
      end

      # If the EDIPI is present, check for SSC eligibility through VAProfile
      if ssc_eligible?
        log_vsc_result(confirmed: true)
        eligible_response
      else
        # If we've hit this point, ICN and EDIPI are present but neither VetVerificationStatus
        # nor VAProfile showed eligible; from here we check the error details to send
        # back to the user
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
      @user_message = SOMETHING_WENT_WRONG_MESSAGE
      VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE
    end

    ##
    # Returns the response for dishonorable discharge
    # Override in subclasses to use different messaging
    #
    # @return [Hash] response with :title, :message, :status keys
    #
    def dishonorable_response
      @user_message = DISHONORABLE_MESSAGE
      VeteranStatusCard::Constants::DISHONORABLE_RESPONSE
    end

    ##
    # Returns the response for ineligible service (no active duty + discharge other than dishonorable)
    # Override in subclasses to use different messaging
    #
    # @return [Hash] response with :title, :message, :status keys
    #
    def ineligible_service_response
      @user_message = INELIGIBLE_SERVICE_MESSAGE
      VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE
    end

    ##
    # Returns the response for unknown service history
    # Override in subclasses to use different messaging
    #
    # @return [Hash] response with :title, :message, :status keys
    #
    def unknown_eligibility_response
      @user_message = UNKNOWN_ELIGIBILITY_MESSAGE
      VeteranStatusCard::Constants::UNKNOWN_ELIGIBILITY_RESPONSE
    end

    ##
    # Returns the response for currently serving members
    # Override in subclasses to use different messaging
    #
    # @return [Hash] response with :title, :message, :status keys
    #
    def currently_serving_response
      @user_message = CURRENTLY_SERVING_MESSAGE
      VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE
    end

    ##
    # Returns the uncaught error response
    # Override in subclasses to use different messaging
    #
    # @return [Hash] response with :title, :message, :status keys
    #
    def uncaught_error_response
      @user_message = UNCAUGHT_ERROR_MESSAGE
      VeteranStatusCard::Constants::UNCAUGHT_ERROR_RESPONSE
    end

    ##
    # Returns the person not found response
    # Override in subclasses to use different messaging
    #
    # @return [Hash] response with :title, :message, :status keys
    #
    def person_not_found_response
      @user_message = PERSON_NOT_FOUND_MESSAGE
      VeteranStatusCard::Constants::PERSON_NOT_FOUND_RESPONSE
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
      return if key.blank?

      StatsD.increment("#{statsd_key_prefix}.#{key.downcase}")
    end

    ##
    # Logs multiple StatsD metrics in a single call
    #
    # @param keys [Array<String>] the metric key suffixes to log
    # @return [void]
    #
    def log_multiple_statsd(keys)
      keys.each do |key|
        log_statsd(key)
      end
    end

    ##
    # Logs metrics and structured result when the user is missing required fields
    # (nil user, missing EDIPI, or missing ICN). Treats the outcome as PERSON_NOT_FOUND.
    #
    # @return [void]
    #
    def log_missing_fields
      keys = [STATSD_INELIGIBLE, @confirmation_status, STATSD_SUCCESS]
      log_multiple_statsd(keys)

      Rails.logger.info("#{service_name} VSC Card Result", {
                          veteran_status: NOT_CONFIRMED_TEXT,
                          not_confirmed_reason: nil,
                          confirmation_status: confirmation_status_upcase,
                          service_summary_code: nil,
                          user_message: PERSON_NOT_FOUND_MESSAGE
                        })
    end

    ##
    # Logs the veteran status card result for metrics and debugging
    #
    # @param confirmed [Boolean] whether the status is 'confirmed' or 'not confirmed'
    # @return [void]
    #
    def log_vsc_result(confirmed: false)
      keys = [
        confirmed ? STATSD_ELIGIBLE : STATSD_INELIGIBLE,
        vet_verification_status[:reason],
        @confirmation_status,
        STATSD_SUCCESS
      ]
      log_multiple_statsd(keys)

      Rails.logger.info("#{service_name} VSC Card Result", {
                          veteran_status: confirmed ? CONFIRMED_TEXT : NOT_CONFIRMED_TEXT,
                          not_confirmed_reason: vet_verification_status[:reason],
                          confirmation_status: confirmation_status_upcase,
                          service_summary_code: ssc_code,
                          user_message: confirmed ? CONFIRMED_MESSAGE : @user_message
                        })
    end

    ##
    # Returns the uppercase version of confirmation_status if not nil
    #
    # @return [String] an uppercase confirmation status
    #
    def confirmation_status_upcase
      @confirmation_status.upcase
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
          edipi: @user&.edipi,
          veteran_status: CONFIRMED_TEXT,
          not_confirmed_reason: vet_verification_status[:reason],
          confirmation_status: confirmation_status_upcase,
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
          veteran_status: NOT_CONFIRMED_TEXT,
          not_confirmed_reason: vet_verification_status[:reason],
          confirmation_status: confirmation_status_upcase,
          service_summary_code: ssc_code
        }
      }
    end

    ##
    # Generates error response details based on the reason for ineligibility
    # Returns appropriate messaging based on vet verification status reason or SSC code
    #
    # @return [Hash] error details with keys :title, :message, :status
    #
    def error_results
      # Vet verification status already has title and message for PERSON_NOT_FOUND, ERROR
      return person_not_found_response if vet_verification_status[:reason] == VET_STATUS_PERSON_NOT_FOUND_TEXT

      return something_went_wrong_response if vet_verification_status[:reason] == VET_STATUS_ERROR_TEXT

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
        @confirmation_status = DISHONORABLE_SSC_MESSAGE
        dishonorable_response
      when *INELIGIBLE_SERVICE_SSC_CODES
        @confirmation_status = INELIGIBLE_SERVICE_SSC_MESSAGE
        ineligible_service_response
      when UNKNOWN_SERVICE_SSC_CODE
        @confirmation_status = UNKNOWN_SSC_MESSAGE
        unknown_eligibility_response
      when EDIPI_NO_PNL_CODE
        @confirmation_status = EDIPI_NO_PNL_SSC_MESSAGE
        unknown_eligibility_response
      when *CURRENTLY_SERVING_CODES
        @confirmation_status = CURRENTLY_SERVING_SSC_MESSAGE
        currently_serving_response
      when *ERROR_SSC_CODES
        @confirmation_status = ERROR_SSC_MESSAGE
        unknown_eligibility_response
      else
        @confirmation_status = UNCAUGHT_SSC_MESSAGE
        uncaught_error_response
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
    # Gets the disability rating from Lighthouse API (memoized)
    # Returns nil if service call fails or user missing ICN
    #
    # @return [Integer, nil] the combined disability rating percentage from Lighthouse or nil on error
    #
    def disability_rating
      return @disability_rating if defined?(@disability_rating)

      @disability_rating = begin
        lighthouse_disabilities_provider.get_combined_disability_rating
      rescue => e
        Rails.logger.error("Disability rating error: #{e.message}", backtrace: e.backtrace)
        nil
      end
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
    # Determines eligibility based on SSC (Service Summary Code) when vet verification
    # returns MORE_RESEARCH_REQUIRED or NOT_TITLE_38
    #
    # @return [Boolean] true if SSC code indicates eligibility, false otherwise
    #
    def ssc_eligible?
      more_research_required_not_title_38? && ssc_confirmed?
    end

    ##
    # Checks whether the SSC code corresponds to a confirmed (eligible) veteran status
    # Sets @confirmation_status as a side effect when a match is found
    #
    # @return [Boolean] true if the SSC code is in any confirmed code group, false otherwise
    #
    def ssc_confirmed?
      case ssc_code
      when *AD_DSCH_VAL_SSC_CODES
        @confirmation_status = AD_DSCH_VAL_SSC_MESSAGE
        true
      when *AD_VAL_PREV_QUAL_SSC_CODES
        @confirmation_status = AD_VAL_PREV_QUAL_SSC_MESSAGE
        true
      when *AD_VAL_PREV_RES_GRD_SSC_CODES
        @confirmation_status = AD_VAL_PREV_RES_GRD_SSC_MESSAGE
        true
      when *AD_UNCHAR_DSCH_SSC_CODES
        @confirmation_status = AD_UNCHAR_DSCH_SSC_MESSAGE
        true
      when *VAL_PREV_QUAL_SSC
        @confirmation_status = VAL_PREV_QUAL_SSC_MESSAGE
        true
      else
        false
      end
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
    # Fires VetVerification, DisabilityRating, and DoD Summary requests in parallel threads.
    # DoD Summary requires EDIPI, so that thread is only started when EDIPI is present.
    # All results are memoized, so subsequent calls within the request are free.
    #
    # @return [void]
    #
    def prefetch_service_data
      futures = [
        Concurrent::Future.execute { vet_verification_response },
        Concurrent::Future.execute { disability_rating }
      ]
      futures << Concurrent::Future.execute { military_personnel_response } if @user.edipi.present?
      futures.each(&:value)
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
            message: unknown_eligibility_response[:message],
            title: unknown_eligibility_response[:title],
            status: unknown_eligibility_response[:status]
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
    # Returns a response for early errors finding no ICN or EDIPI
    #
    # @return [Hash] formatted error response with :type, :veteran_status, :service_summary_code,
    #    :not_confirmed_reason, :confirmation_status
    #
    def person_not_found_response_hash
      response = person_not_found_response
      {
        type: VETERAN_STATUS_ALERT,
        attributes: {
          header: response[:title],
          body: response[:message],
          alert_type: response[:status],
          veteran_status: NOT_CONFIRMED_TEXT,
          not_confirmed_reason: VET_STATUS_PERSON_NOT_FOUND_TEXT,
          confirmation_status: confirmation_status_upcase,
          service_summary_code: nil
        }
      }
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
          veteran_status: NOT_CONFIRMED_TEXT,
          not_confirmed_reason: vet_verification_status[:reason],
          confirmation_status: confirmation_status_upcase,
          service_summary_code: ssc_code
        }
      }
    end
  end
end
