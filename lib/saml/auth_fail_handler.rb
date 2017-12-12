# frozen_string_literal: true
module SAML
  class AuthFailHandler
    attr_accessor :message, :level, :context

    CLICKED_DENY_MSG = 'Subject did not consent to attribute release'
    TOO_LATE_MSG     = 'Current time is on or after NotOnOrAfter condition'
    TOO_EARLY_MSG    = 'Current time is earlier than NotBefore condition'

    KNOWN_ERRORS = %i(clicked_deny auth_too_late auth_too_early).freeze

    def initialize(saml_response)
      @saml_response = saml_response
      return if @saml_response.is_valid?
      initialize_errors!
    end

    def error
      KNOWN_ERRORS.each do |known_error|
        return known_error if send("#{known_error}?")
      end

      only_one_error? ? 'unknown' : 'multiple'
    end

    def errors?
      !@message.nil? && !@level.nil?
    end

    private

    def initialize_errors!
      KNOWN_ERRORS.each do |known_error|
        break if send("#{known_error}?")
      end

      generic_error_message
    end

    def generic_error_message
      context = {
        saml_response: {
          status_message: @saml_response.status_message,
          errors: @saml_response.errors
        }
      }
      set_sentry_params('Other SAML Response Error(s)', :error, context)
    end

    def clicked_deny?
      return false unless only_one_error? && @saml_response.status_message == CLICKED_DENY_MSG
      set_sentry_params(CLICKED_DENY_MSG, :warn)
    end

    def auth_too_late?
      return false unless only_one_error? && @saml_response.errors[0].include?(TOO_LATE_MSG)
      set_sentry_params(TOO_LATE_MSG, :warn, @saml_response.errors[0])
    end

    def auth_too_early?
      return false unless only_one_error? && @saml_response.errors[0].include?(TOO_EARLY_MSG)
      set_sentry_params(TOO_EARLY_MSG, :error, @saml_response.errors[0])
    end

    def only_one_error?
      @saml_response.errors.size == 1
    end

    def set_sentry_params(msg, level, ctx = {})
      @message = 'Login Fail! ' + msg
      @level   = level
      @context = ctx
    end
  end
end
