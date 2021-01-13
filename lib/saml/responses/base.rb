# frozen_string_literal: true

module SAML
  module Responses
    module Base
      CLICKED_DENY_ERROR_CODE = '001'
      AUTH_TOO_EARLY_ERROR_CODE = '003'
      AUTH_TOO_LATE_ERROR_CODE = '005'
      UNKNOWN_OR_BLANK_ERROR_CODE = '007'
      ERRORS = { clicked_deny: { code: CLICKED_DENY_ERROR_CODE,
                                 tag: :clicked_deny,
                                 short_message: 'Subject did not consent to attribute release',
                                 level: :warn },
                 auth_too_late: { code: AUTH_TOO_LATE_ERROR_CODE,
                                  tag: :auth_too_late,
                                  short_message: 'Current time is on or after NotOnOrAfter condition',
                                  level: :warn },
                 auth_too_early: { code: AUTH_TOO_EARLY_ERROR_CODE,
                                   tag: :auth_too_early,
                                   short_message: 'Current time is earlier than NotBefore condition',
                                   level: :error },
                 blank: { code: UNKNOWN_OR_BLANK_ERROR_CODE,
                          tag: :blank,
                          short_message: 'Blank response',
                          level: :error },
                 unknown: { code: UNKNOWN_OR_BLANK_ERROR_CODE,
                            tag: :unknown,
                            short_message: 'Other SAML Response Error(s)',
                            level: :error } }.freeze

      def normalized_errors
        @normalized_errors ||= []
      end

      def errors_hash
        normalized_errors.first
      end

      def errors_context
        normalized_errors
      end

      def error_code
        errors_hash[:code] if errors.any?
      end

      def error_instrumentation_code
        "error:#{errors_hash[:tag]}" if errors.any?
      end

      def valid?
        @normalized_errors = []
        # passing true collects all validation errors
        is_valid_result = validate(true)
        errors.each do |error_message|
          normalized_errors << map_message_to_error(error_message).merge(full_message: error_message)
        end
        is_valid_result
      end

      def map_message_to_error(error_message)
        ERRORS.each_key do |key|
          return ERRORS[key] if error_message.include?(ERRORS[key][:short_message])
        end
        ERRORS[:unknown]
      end

      def issuer_text
        response_doc = assertion_encrypted? ? decrypted_document : document
        REXML::XPath.first(response_doc, '//saml:Issuer')&.text
      end

      def authn_context_text
        response_doc = assertion_encrypted? ? decrypted_document : document
        return nil if response_doc.blank?

        REXML::XPath.first(response_doc, '//saml:AuthnContextClassRef')&.text
      end

      def authn_context
        authn_context_text || SAML::User::UNKNOWN_AUTHN_CONTEXT
      end
    end
  end
end
