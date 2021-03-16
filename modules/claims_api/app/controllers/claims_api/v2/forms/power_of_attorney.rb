module ClaimsApi
  module V2
    module Forms
      class PowerOfAttorney < ClaimsApi::V2::Base
        version 'v2'

        resource 'veterans/:veteranId' do
          resource 'forms/21-22' do
            desc 'Submit a claim.' do
              success code: 202, model: ClaimsApi::Entities::V2::ClaimSubmittedEntity
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
              status 202

              raise 'NotImplemented'
            end
          end

          resource 'forms/21-22a' do
            desc 'Submit a claim.' do
              success code: 202, model: ClaimsApi::Entities::V2::ClaimSubmittedEntity
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
              status 202

              raise 'NotImplemented'
            end
          end
        end
      end
    end
  end
end
