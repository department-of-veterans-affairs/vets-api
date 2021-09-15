# frozen_string_literal: true

module V1
  module Lorota
    class ClaimsToken < BasicClaimsToken
      def claims
        {
          aud: 'lorota',
          iss: 'vets-api',
          sub: check_in.uuid,
          scopes: ['read.full'],
          iat: issued_at_time,
          exp: expires_at_time
        }
      end
    end
  end
end
