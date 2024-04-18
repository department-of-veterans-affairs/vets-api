# frozen_string_literal: true

# rubocop:disable Layout/LineLength
module Swagger
  module Requests
    class SignIn
      include Swagger::Blocks

      swagger_path '/v0/sign_in/authorize' do
        operation :get do
          key :description, 'Initializes Sign in Service authorization & authentication.'
          key :operationId, 'getSignInAuthorize'
          key :tags, %w[authentication]

          key :produces, ['text/html']
          key :consumes, ['application/json']

          parameter do
            key :name, 'type'
            key :in, :query
            key :description, 'Credential provider selected to authenticate with. Values: `logingov`, `idme`, `mhv`, `dslogon`'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'client_id'
            key :in, :query
            key :description, 'Determines cookie (web) vs. API (mobile) authentication. Values: `web`, `mobile`.'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'acr'
            key :in, :query
            key :description, 'Level of authentication requested, dependant on CSP. Values: `loa1`, `loa3`, `ial1`, `ial2`, `min`.'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'code_challenge'
            key :in, :query
            key :description, 'Value created from a `code_verifier` hex that is hash and encoded.'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'code_challenge_method'
            key :in, :query
            key :description, 'Method used to create code_challenge (*must* equal `S256`).'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'state'
            key :in, :query
            key :description, 'Client-provided code that is returned to the client upon successful authentication. Minimum length is 22 characters.'
            key :required, false
            key :type, :string
          end

          response 200 do
            key :description, 'User is redirected to credential service provider via a frontend form submission.'
            schema { key :$ref, :CSPAuthFormResponse }
          end
        end
      end

      swagger_path '/v0/sign_in/callback' do
        operation :get do
          key :description, 'Sign in Service authentication callback.'
          key :operationId, 'getSignInCallback'
          key :tags, %w[authentication]

          key :produces, ['text/html']
          key :consumes, ['application/json']

          parameter do
            key :name, 'code'
            key :in, :query
            key :description, 'Authentication code created by the credential provider & used to obtain tokens from them.'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'state'
            key :in, :query
            key :description, 'Encoded payload that includes information passed from vets-api to credential provider in `/authorize` call.'
            key :required, true
            key :type, :string
          end

          response 302 do
            key :description, 'User object is created in vets-api, then redirected back to client with an authentication code that can be used to obtain tokens. If a `state` param was included in the original `/authorize` request it will be returned here.'
            schema do
              key :type, :string
              key :format, :uri
              key :example, 'vamobile://login-success?code=0c2d21d3-465b-4054-8030-1d042da4f667&state=d940a929b7af6daa595707d0c99bec57'
            end
          end
        end
      end

      swagger_path '/v0/sign_in/token' do
        operation :post do
          key :description, 'Sign in Service session creation & tokens request.'
          key :operationId, 'postSignInToken'
          key :tags, %w[authentication]

          key :produces, ['application/json']
          key :consumes, ['application/json']

          parameter do
            key :name, 'grant_type'
            key :in, :query
            key :description, 'Authentication grant type value, must equal `authorization_code`.'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'code'
            key :in, :query
            key :description, 'Authentication code passed to the client through the `code` param in authentication `/callback` redirect.'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'code_verifier'
            key :in, :query
            key :description, 'Original hex that was hashed and SHA256-encoded to create the `code_challenge` used in the `/authenticate` request.'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Authentication code and code_verifier validated, session and tokens created & tokens returned to client.'
            schema { key :$ref, :TokenResponse }
          end
        end
      end

      swagger_path '/v0/sign_in/refresh' do
        operation :post do
          key :description, 'Sign in Service session & tokens refresh.'
          key :operationId, 'postSignInRefresh'
          key :tags, %w[authentication]

          key :produces, ['application/json']
          key :consumes, ['application/json']

          parameter do
            key :name, 'refresh_token'
            key :in, :query
            key :description, 'Refresh token string.'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'anti_csrf_token'
            key :in, :query
            key :description, 'Anti CSRF token, used to match `/refresh` calls with the `token` call that generated the refresh token used - currently disabled, this can be ignored.'
            key :required, false
            key :type, :string
          end

          response 200 do
            key :description, 'Refresh token validated, session updated, new tokens created and returned to client.'
            schema { key :$ref, :TokenResponse }
          end
        end
      end

      swagger_path '/v0/sign_in/revoke' do
        operation :post do
          key :description, 'Sign in Service session destruction.'
          key :operationId, 'postSignInRevoke'
          key :tags, %w[authentication]

          key :produces, ['application/json']
          key :consumes, ['application/json']

          parameter do
            key :name, 'refresh_token'
            key :in, :query
            key :description, 'Refresh token string, must be URI-encoded.'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'anti_csrf_token'
            key :in, :query
            key :description, 'Anti CSRF token, used to match `refresh` calls with the `token` call that generated the refresh token used - currently disabled, this can be ignored.'
            key :required, false
            key :type, :string
          end

          response 200 do
            key :description, 'Refresh token validated & session destroyed, invalidating connected tokens.'
          end
        end
      end

      swagger_path '/v0/sign_in/revoke_all_sessions' do
        operation :get do
          key :description, 'Sign in Service destruction of all of a user\'s sessions.'
          key :operationId, 'getSignInRevokeAll'
          key :tags, %w[authentication]

          key :produces, ['application/json']
          key :consumes, ['application/json']

          parameter :optional_authorization

          response 200 do
            key :description, 'Access token validated & included `user_uuid` used to look up & destroy all of a user\'s sessions.'
            schema {}
          end
        end
      end

      swagger_path '/v0/sign_in/logout' do
        operation :get do
          key :description, 'User-initiated logout of their Sign in Service session.'
          key :operationId, 'getSignInLogout'
          key :tags, %w[authentication]

          key :produces, ['application/json']
          key :consumes, ['application/json']

          parameter :optional_authorization

          response 302 do
            key :description, 'Access token validated & session destroyed, invalidating connected tokens. User is redirected to credential provider to end their session, then redirect back to VA.gov frontend.'
            schema { key :$ref, :LogoutRedirectResponse }
          end
        end
      end
    end
  end
end
# rubocop:enable Layout/LineLength
