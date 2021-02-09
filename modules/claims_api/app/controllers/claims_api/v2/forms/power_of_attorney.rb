module ClaimsApi
  module V2
    module Forms
      class PowerOfAttorney < ClaimsApi::V2::Base
        version 'v2'

        resource 'forms/2122' do
          desc 'Submit a claim.' do
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
