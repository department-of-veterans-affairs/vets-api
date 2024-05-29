# frozen_string_literal: true

module SignIn
  class TokenParamsValidator
    include ActiveModel::Validations

    attr_reader :grant_type, :code, :code_verifier, :client_assertion, :client_assertion_type, :assertion

    # rubocop:disable Rails/I18nLocaleTexts
    validates :grant_type, inclusion: {
      in: [
        Constants::Auth::AUTH_CODE_GRANT,
        Constants::Auth::JWT_BEARER_GRANT
      ],
      message: 'is not valid'
    }

    with_options if: :authorization_code_grant? do
      validates :client_assertion_type, inclusion: {
        in: [Constants::Auth::CLIENT_ASSERTION_TYPE],
        message: 'is not valid'
      }, if: :client_assertion_type_present?

      validates :code, :client_assertion, :client_assertion_type, presence: true, if: :client_assertion_type_present?

      validates :code, :code_verifier, presence: true, unless: :client_assertion_type_present?
    end
    # rubocop:enable Rails/I18nLocaleTexts

    with_options if: :jwt_bearer_grant? do
      validates :assertion, presence: true
    end

    def initialize(params:)
      @grant_type = params[:grant_type]
      @code = params[:code]
      @code_verifier = params[:code_verifier]
      @client_assertion = params[:client_assertion]
      @client_assertion_type = params[:client_assertion_type]
      @assertion = params[:assertion]
    end

    def perform
      validate!
    rescue ActiveModel::ValidationError => e
      log_error_and_raise(e.model.errors.full_messages.to_sentence)
    rescue => e
      log_error_and_raise(e.message)
    end

    private

    def authorization_code_grant?
      grant_type == Constants::Auth::AUTH_CODE_GRANT
    end

    def jwt_bearer_grant?
      grant_type == Constants::Auth::JWT_BEARER_GRANT
    end

    def client_assertion_type_present?
      client_assertion_type.present?
    end

    def log_error_and_raise(message)
      Rails.logger.error('[SignIn::TokenParamsValidator] error', { errors: message })
      raise Errors::MalformedParamsError.new(message:)
    end
  end
end
