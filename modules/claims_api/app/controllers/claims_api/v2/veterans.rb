module ClaimsApi
  module V2
    class Veterans < ClaimsApi::V2::Base
      version 'v2'

      before do
        authenticate
      end

      resource :veteran do
        desc 'Generate unique identifier for Veteran.' do
          success ClaimsApi::Entities::V2::VeteranTokenEntity
          failure [
            [401, 'Unauthorized', 'ClaimsApi::Entities::V2::ErrorsEntity'],
            [400, 'Bad Request', 'ClaimsApi::Entities::V2::ErrorsEntity']
          ]
          tags ['Veteran Identifiers']
          security [{ bearer_token: [] }]
        end
        params do
          requires :ssn, type: String, regexp: /^\d{9}$/, documentation: { param_type: 'body' }
          requires :birthdate, type: String, regexp: /^\d{4}-\d{2}-\d{2}$/
          requires :firstName, type: String
          requires :lastName, type: String
        end
        post :token do
          # TODO: Logic here to ensure only valid consumers can generate a token for the provided Veteran
          #  1. the Veteran themself
          #  2. a representative with power of attorney for the provided Veteran

          token = Base64.urlsafe_encode64(JWT.encode(params, Rails.application.secrets.secret_key_base))
          token_container = { token: token }
          present token_container, with: ClaimsApi::Entities::V2::VeteranTokenEntity
        end
      end
    end
  end
end
