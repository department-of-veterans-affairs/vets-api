# frozen_string_literal: true

module Swagger
  module Requests
    class Sessions
      include Swagger::Blocks

      swagger_path '/v0/sessions/authn_urls' do
        operation :get do
          key :description, 'Fetch various urls for initiating authentication'
          key :tags, %w[authentication]

          response 200 do
            key :description, 'returns a list of urls for invoking SAML authentication flow'
            schema do
              key :'$ref', :AuthenticationURLs
            end
          end
        end
      end

      swagger_path '/v0/sessions/multifactor' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Fetch url for invoking multifactor policy'
          key :tags, %w[authentication]

          parameter do
            key :name, 'Authorization'
            key :in, :header
            key :description, 'The authorization method and token value'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'returns a url for triggering the multifactor policy when previously declined'
            schema do
              key :'$ref', :MultifactorURL
            end
          end
        end
      end

      swagger_path '/v0/sessions/identity_proof' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Fetch url for verifying identity (or triggering ID.me FICAM flow)'
          key :tags, %w[authentication]

          parameter do
            key :name, 'Authorization'
            key :in, :header
            key :description, 'The authorization method and token value'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'returns a url for triggering identity proof verification / FICAM flow.'
            schema do
              key :'$ref', :IdentityProofURL
            end
          end
        end
      end

      swagger_path '/v0/sessions' do
        operation :delete do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Fetch url for terminating a session'
          key :operationId, 'endSession'
          key :tags, %w[authentication]

          parameter do
            key :name, 'Authorization'
            key :in, :header
            key :description, 'The authorization method and token value'
            key :required, true
            key :type, :string
          end

          response 202 do
            key :description, 'returns a url to invoke SAML logout process'
            schema do
              key :'$ref', :LogoutURL
            end
          end
        end
      end

      swagger_schema :AuthenticationURLs, required: %i[mhv dslogon idme] do
        property :mhv, type: :string
        property :dslogon, type: :string
        property :idme, type: :string
      end

      swagger_schema :MultifactorURL, required: [:multifactor_url] do
        property :multifactor_url, type: :string
      end

      swagger_schema :IdentityProofURL, required: [:identity_proof_url] do
        property :identity_proof_url, type: :string
      end

      swagger_schema :LogoutURL, required: [:logout_via_get] do
        property :logout_via_get, type: :string
      end
    end
  end
end
