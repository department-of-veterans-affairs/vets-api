# frozen_string_literal: true

module SAML
  class Response < OneLogin::RubySaml::Response
    ERRORS = { clicked_deny:   { code: '001',
                                 tag: :clicked_deny,
                                 short_message: 'Subject did not consent to attribute release',
                                 level: :warn },
               auth_too_late:  { code: '002',
                                 tag: :auth_too_late,
                                 short_message: 'Current time is on or after NotOnOrAfter condition',
                                 level: :warn },
               auth_too_early: { code: '003',
                                 tag: :auth_too_early,
                                 short_message: 'Current time is earlier than NotBefore condition',
                                 level: :error },
               multiple:       { code: '007',
                                 tag: :multiple,
                                 short_message: 'Multiple SAML Errors',
                                 level: :error },
               blank:           { code: '007',
                                  tag: :blank,
                                  short_message: 'Blank response',
                                  level: :error },
               unknown:         { code: '007',
                                  tag: :unknown,
                                  short_message: 'Other SAML Response Error(s)',
                                  level: :error } }.freeze

    def normalized_errors
      @normalized_errors ||= []
    end

    def valid?
      @normalized_errors = []
      # passing true collects all validation errors
      is_valid_result = is_valid?(true)
      errors.each do |error_message|
        normalized_errors << normalize_error(error_message)
      end.compact
      normalized_errors << ERRORS[:multiple] if normalized_errors.length > 1
      is_valid_result
    end

    def normalize_error(error_message)
      error_hash = ERRORS[:unknown]
      ERRORS.each_key do |key|
        if error_message.include?(ERRORS[key][:short_message])
          error_hash = ERRORS[key]
          break
        end
      end
      error_hash[:full_message] = error_message
      error_hash
    end

    def authn_context
      if decrypted_document
        REXML::XPath.first(decrypted_document, '//saml:AuthnContextClassRef')&.text ||
          SAML::User::UNKNOWN_AUTHN_CONTEXT
      else
        SAML::User::UNKNOWN_AUTHN_CONTEXT
      end
    end
  end
end
