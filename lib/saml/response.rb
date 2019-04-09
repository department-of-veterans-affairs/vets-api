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
      Raven.extra_context(saml_response_errors: errors) unless errors.empty?
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

    def authn_context_text
      REXML::XPath.first(decrypted_document, '//saml:AuthnContextClassRef')&.text
    end

    def authn_context
      if decrypted_document
        authn_context_text || SAML::User::UNKNOWN_AUTHN_CONTEXT
      else
        SAML::User::UNKNOWN_AUTHN_CONTEXT
      end
    end
  end
end
