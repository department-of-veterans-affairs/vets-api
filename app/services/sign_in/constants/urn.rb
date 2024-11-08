# frozen_string_literal: true

module SignIn
  module Constants
    module Urn
      ACCESS_TOKEN = 'urn:ietf:params:oauth:token-type:access_token'
      DEVICE_SECRET = 'urn:x-oath:params:oauth:token-type:device-secret'
      JWT_BEARER_CLIENT_AUTHENTICATION = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
      JWT_BEARER_GRANT_TYPE = 'urn:ietf:params:oauth:grant-type:jwt-bearer'
      JWT_TOKEN = 'urn:ietf:params:oauth:token-type:jwt'
      TOKEN_EXCHANGE_GRANT_TYPE = 'urn:ietf:params:oauth:grant-type:token-exchange'
    end
  end
end
