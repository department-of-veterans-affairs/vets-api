# frozen_string_literal: true

module MebApi
  # Configuration and constants for MEB confirmation emails
  module ConfirmationEmailConfig
    # Form type identifiers
    FORM_1990MEB = '1990MEB'
    FORM_1990EMEB = '1990EMEB'

    # StatsD metric tags
    TAG_1990MEB = 'form:1990meb'
    TAG_1990EMEB = 'form:1990emeb'

    # Normalized claim statuses for metrics (prevent unbounded cardinality)
    VALID_CLAIM_STATUSES = %w[ELIGIBLE DENIED PENDING OFFRAMP].freeze

    # Template ID mappings by form type and status
    TEMPLATE_MAPPINGS = {
      FORM_1990MEB => {
        'ELIGIBLE' => :form1990meb_approved_confirmation_email,
        'DENIED' => :form1990meb_denied_confirmation_email,
        'OFFRAMP' => :form1990meb_offramp_confirmation_email
      },
      FORM_1990EMEB => {
        'ELIGIBLE' => :form1990emeb_approved_confirmation_email,
        'DENIED' => :form1990emeb_denied_confirmation_email,
        'OFFRAMP' => :form1990emeb_offramp_confirmation_email
      }
    }.freeze

    class << self
      # Normalize claim status to prevent unbounded metric cardinality
      # @param status [String, Symbol] Raw claim status
      # @return [String] Normalized status (ELIGIBLE, DENIED, PENDING, OFFRAMP, or OTHER)
      def normalize_claim_status(status)
        normalized = status.to_s.upcase
        VALID_CLAIM_STATUSES.include?(normalized) ? normalized : 'OTHER'
      end

      # Get template ID for a confirmation email
      # @param form_type [String] '1990MEB' or '1990EMEB'
      # @param claim_status [String] Status of the claim
      # @return [String] VANotify template ID
      def template_id(form_type:, claim_status:)
        status_key = case claim_status.to_s.upcase
                     when 'ELIGIBLE', 'DENIED' then claim_status.to_s.upcase
                     else 'OFFRAMP'
                     end

        template_key = TEMPLATE_MAPPINGS.dig(form_type, status_key) ||
                       TEMPLATE_MAPPINGS.dig(form_type, 'OFFRAMP')

        Settings.vanotify.services.va_gov.template_id.public_send(template_key)
      end
    end
  end
end
