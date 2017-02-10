# frozen_string_literal: true
module SAML
  module AuthResponseHandling
    CLICKED_DENY_MSG = 'Subject did not consent to attribute release'
    TOO_LATE_MSG     = 'Current time is on or after NotOnOrAfter condition'
    TOO_EARLY_MSG    = 'Current time is earlier than NotBefore condition'

    def clicked_deny?
      only_one_error? && @saml_response.status_message == CLICKED_DENY_MSG
    end

    def auth_too_late?
      only_one_error? && @saml_response.errors[0].include?(TOO_LATE_MSG)
    end

    def auth_too_early?
      only_one_error? && @saml_response.errors[0].include?(TOO_EARLY_MSG)
    end

    def only_one_error?
      @saml_response.errors.size == 1
    end

    def generic_login_error
      message = <<-MESSAGE.strip_heredoc
        SAML Login attempt failed! Reasons...
          saml:    'valid?=#{@saml_response.is_valid?} errors=#{@saml_response.errors}'
          user:    'valid?=#{@current_user&.valid?} errors=#{@current_user&.errors&.full_messages}'
          session: 'valid?=#{@session&.valid?} errors=#{@session&.errors&.full_messages}'
      MESSAGE
      message
    end
  end
end
