module ClaimsApi
  module V2
    module Forms
      class PowerOfAttorney < ClaimsApi::V2::Base
        version 'v2'

        resource 'forms/2122' do
          desc 'Submit a claim.' do
            success code: 202, model: ClaimsApi::Entities::V2::ClaimSubmittedEntity
            failure [
              [401, 'Unauthorized', 'ClaimsApi::Entities::V2::ErrorsEntity'],
              [400, 'Bad Request', 'ClaimsApi::Entities::V2::ErrorsEntity']
            ]
            tags ['Power of Attorney']
            security [{ bearer_token: [] }]
          end
          post '/' do
            status 202

            raise 'NotImplemented'
          end
        end
      end
    end
  end
end
