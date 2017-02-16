# frozen_string_literal: true
module SAML
  class AuthFailHandler
    attr_accessor :message, :level, :context

    CLICKED_DENY_MSG = 'Subject did not consent to attribute release'
    TOO_LATE_MSG     = 'Current time is on or after NotOnOrAfter condition'
    TOO_EARLY_MSG    = 'Current time is earlier than NotBefore condition'

    def initialize(saml_response, user, session)
      @saml_response = saml_response
      @current_user = user
      @session = session

      @message = nil
      @level   = nil
      @context = nil
    end

    def known_error?
      known_errors = [
        :clicked_deny?,
        :auth_too_late?,
        :auth_too_early?
      ]

      known_errors.each do |known_error|
        break if send(known_error)
      end

      !@message.nil? && !@level.nil?
    end

    def generic_error_message
      message = <<-MESSAGE.strip_heredoc
        SAML Login attempt failed! Reasons...
          saml:    'valid?=#{@saml_response.is_valid?} errors=#{@saml_response.errors}'
          user:    'valid?=#{@current_user&.valid?} errors=#{@current_user&.errors&.full_messages}'
          session: 'valid?=#{@session&.valid?} errors=#{@session&.errors&.full_messages}'
      MESSAGE
      message
    end

    private

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
