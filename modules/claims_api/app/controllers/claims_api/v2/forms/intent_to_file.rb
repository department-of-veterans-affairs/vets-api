module ClaimsApi
  module V2
    module Forms
      class IntentToFile < ClaimsApi::V2::Base
        version 'v2'

        resource 'forms/0966' do
          desc 'Submit a claim.' do
            success ClaimsApi::Entities::V2::ClaimSubmittedEntity
            failure [
              [401, 'Unauthorized', 'ClaimsApi::Entities::V2::ErrorsEntity'],
              [400, 'Bad Request', 'ClaimsApi::Entities::V2::ErrorsEntity']
            ]
            tags ['Intent to File']
            security [{ bearer_token: [] }]
          end
          post '/' do
            raise 'NotImplemented'
          end
        end
      end
    end
  end
end
