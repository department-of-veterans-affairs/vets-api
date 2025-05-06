# frozen_string_literal: true

require 'jwt'

module ClaimsApi
  class JwtEncoder
    def encode_va_notify_jwt(alg, service_id, client_secret)
      headers = va_notify_headers(alg)

      data = va_notify_data(service_id)

      JWT.encode(data, client_secret, alg, headers)
    end

    private

    def va_notify_headers(alg)
      {
        typ: 'JWT',
        alg:
      }
    end

    def va_notify_data(service_id)
      {
        iss: service_id,
        iat: current_timestamp_in_seconds
      }
    end

    def current_timestamp_in_seconds
      Time.now.to_i
    end
  end
end
