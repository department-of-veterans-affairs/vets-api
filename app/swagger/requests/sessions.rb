# frozen_string_literal: true

module Swagger
  module Requests
    class Sessions
      include Swagger::Blocks

      swagger_path '/sessions/mhv/new' do
        operation :get do
          key :description, 'Get url for initiating SSO with MyHealtheVet'
          key :tags, %w[authentication]

          response 200 do
            key :description, 'returns the url for invoking SAML authentication flow via MyHealtheVet'
            schema do
              key :'$ref', :AuthenticationURL
            end
          end
        end
      end

      swagger_path '/sessions/dslogon/new' do
        operation :get do
          key :description, 'Get url for initiating SSO with DS Logon'
          key :tags, %w[authentication]

          response 200 do
            key :description, 'returns the url for invoking SAML authentication flow via DS Logon'
            schema do
              key :'$ref', :AuthenticationURL
            end
          end
        end
      end

      swagger_path '/sessions/idme/new' do
        operation :get do
          key :description, 'Get url for initiating SSO with Id.me'
          key :tags, %w[authentication]

          response 200 do
            key :description, 'returns the url for invoking SAML authentication flow via Id.me'
            schema do
              key :'$ref', :AuthenticationURL
            end
          end
        end
      end

      swagger_path '/sessions/mfa/new' do
        operation :get do
          key :description, 'Get url for initiating enabling multifactor authentication'
          key :tags, %w[authentication]

          parameter do
            key :name, 'Authorization'
            key :in, :header
            key :description, 'The authorization method and token value'
            key :required, true
            key :type, :string
          end

          response 401 do
            key :description, 'Unauthorized User'
            schema do
              key :'$ref', :Errors
            end
          end

          response 200 do
            key :description, 'returns the url to enable multifactor authentication'
            schema do
              key :'$ref', :AuthenticationURL
            end
          end
        end
      end

      swagger_path '/sessions/verify/new' do
        operation :get do
          key :description, 'Get url for initiating FICAM identity proofing'
          key :tags, %w[authentication]

          parameter do
            key :name, 'Authorization'
            key :in, :header
            key :description, 'The authorization method and token value'
            key :required, true
            key :type, :string
          end

          response 401 do
            key :description, 'Unauthorized User'
            schema do
              key :'$ref', :Errors
            end
          end

          response 200 do
            key :description, 'returns the url to initiate FICAM identity proofing flow'
            schema do
              key :'$ref', :AuthenticationURL
            end
          end
        end
      end

      swagger_path '/sessions/slo/new' do
        operation :get do
          key :description, 'Get url for terminating session and initiating SLO flow'
          key :tags, %w[authentication]

          parameter do
            key :name, 'Authorization'
            key :in, :header
            key :description, 'The authorization method and token value'
            key :required, true
            key :type, :string
          end

          response 401 do
            key :description, 'Unauthorized User'
            schema do
              key :'$ref', :Errors
            end
          end

          response 200 do
            key :description, 'returns the url to terminate the current session and initiates external SLO flow'
            schema do
              key :'$ref', :AuthenticationURL
            end
          end
        end
      end

      swagger_schema :AuthenticationURL, required: %i[url] do
        property :url, type: :string
      end
    end
  end
end
