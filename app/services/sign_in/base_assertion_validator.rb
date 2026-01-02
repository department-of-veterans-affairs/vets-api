# frozen_string_literal: true

module SignIn
  class BaseAssertionValidator
    private

    def decode_assertion!(assertion)
      payload, _header = JWT.decode(assertion, nil, true, jwt_decode_options, &method(:jwt_keyfinder))
      payload.deep_symbolize_keys
    rescue JWT::InvalidAudError, JWT::InvalidIatError, JWT::InvalidIssuerError,
           JWT::InvalidSubError, JWT::MissingRequiredClaim => e
      raise attributes_error_class.new(message: e.message)
    rescue JWT::VerificationError
      raise signature_mismatch_error_class.new(message: signature_mismatch_message)
    rescue JWT::ExpiredSignature
      raise expired_error_class.new(message: expired_message)
    rescue JWT::DecodeError
      raise malformed_error_class.new(message: malformed_message)
    end

    def jwt_keyfinder(_header, _payload)
      certs = active_certs
      raise Errors::AssertionCertificateExpiredError.new message: 'Certificates are expired' if certs.blank?

      certs.map(&:public_key)
    end

    def hostname
      return localhost_hostname if Settings.vsp_environment == 'localhost'
      return staging_hostname if Settings.review_instance_slug.present?

      "https://#{Settings.hostname}"
    end

    def algorithm                      = Constants::Auth::ASSERTION_ENCODE_ALGORITHM
    def token_route                    = "#{hostname}#{Constants::Auth::TOKEN_ROUTE_PATH}"
    def staging_hostname               = 'https://staging-api.va.gov'
    def localhost_hostname             = "http://localhost:#{URI("http://#{Settings.hostname}").port}"
    def signature_mismatch_message     = 'Assertion body does not match signature'
    def expired_message                = 'Assertion has expired'
    def malformed_message              = 'Assertion is malformed'
    def attributes_error_class         = raise NotImplementedError
    def signature_mismatch_error_class = raise NotImplementedError
    def expired_error_class            = raise NotImplementedError
    def malformed_error_class          = raise NotImplementedError
    def active_certs                   = raise NotImplementedError
  end
end
