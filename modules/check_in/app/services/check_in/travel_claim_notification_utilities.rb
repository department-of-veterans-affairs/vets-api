# frozen_string_literal: true

module CheckIn
  # Shared utilities for travel claim notification job and callback
  # Centralizes common logic to maintain DRY principles
  module TravelClaimNotificationUtilities
    module_function

    def self.included(base)
      base.extend(self)
    end

    # Determines facility type based on template ID
    # @param template_id [String] The template ID
    # @return [String] 'oh' or 'cie'
    def determine_facility_type_from_template(template_id)
      if template_id == 'oh-failure-template-id' ||
         [Constants::OH_FAILURE_TEMPLATE_ID, Constants::OH_ERROR_TEMPLATE_ID,
          Constants::OH_TIMEOUT_TEMPLATE_ID, Constants::OH_SUCCESS_TEMPLATE_ID,
          Constants::OH_DUPLICATE_TEMPLATE_ID].include?(template_id)
        'oh'
      else
        'cie'
      end
    end

    # Checks if a template represents a failure notification
    # @param template_id [String] The template ID to check
    # @return [Boolean] true if this is a failure template
    def failure_template?(template_id)
      return true if TravelClaimBaseJob::FAILED_CLAIM_TEMPLATE_IDS.include?(template_id)
      return true if template_id == 'oh-failure-template-id'
      return true if template_id == 'cie-failure-template-id'

      false
    end

    # Increments silent failure metrics based on template and facility type
    # @param template_id [String] The template ID
    # @param facility_type [String] The facility type ('oh' or 'cie')
    def increment_silent_failure_metrics(template_id, facility_type)
      return unless failure_template?(template_id)

      facility_type = determine_facility_type_from_template(template_id) if facility_type.nil?

      tags = if facility_type == 'oh'
               Constants::STATSD_OH_SILENT_FAILURE_TAGS
             else
               Constants::STATSD_CIE_SILENT_FAILURE_TAGS
             end

      StatsD.increment(Constants::STATSD_NOTIFY_SILENT_FAILURE, tags:)
    end

    # Extracts phone number last four digits safely
    # @param phone_number [String, nil] The phone number
    # @return [String] Last four digits or 'unknown'
    def extract_phone_last_four(phone_number)
      return 'unknown' if phone_number.blank?

      cleaned_number = phone_number.gsub(/[-.\s()]/, '')
      digits = cleaned_number.delete('^0-9')
      return 'unknown' if digits.empty?

      digits.last(4)
    end
  end
end
