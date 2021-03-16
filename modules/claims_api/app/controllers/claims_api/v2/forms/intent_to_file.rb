module ClaimsApi
  module V2
    module Forms
      class IntentToFile < ClaimsApi::V2::Base
        version 'v2'

        resource 'veterans/:veteranId' do
          resource 'forms/21-0966' do
            desc 'Submit a claim.' do
              success ClaimsApi::Entities::V2::ClaimSubmittedEntity
              failure [
                [401, 'Unauthorized', 'ClaimsApi::Entities::V2::ErrorsEntity'],
                [400, 'Bad Request', 'ClaimsApi::Entities::V2::ErrorsEntity']
              ]
              tags ['Forms']
              security [{ bearer_token: [] }]
            end
            params do
              requires :token, type: String
            end
            post '/' do
              raise 'NotImplemented'
            end
          end
        end
      end
    end
  end
end
