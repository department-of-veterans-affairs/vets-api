# frozen_string_literal: true

module ClaimsApi
  module V1
    module AuthHeadersLookup
      AUTH_HEADER_V1_KEYS = {
        pnid: :va_eauth_pnid,
        birls_file_number: :va_eauth_birlsfilenumber,
        first_name: :va_eauth_firstName,
        last_name: :va_eauth_lastName,
        birth_date: :va_eauth_birthdate
      }.freeze

      def get_auth_header(header_key)
        key = AUTH_HEADER_V1_KEYS[header_key]
        # This raise should never happen if we have made it to this point
        raise ArgumentError, "Unknown auth header key: #{header_key}" unless key

        @auth_headers[key]
      end
    end
  end
end
