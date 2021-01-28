module ClaimsApi
  module V2
    module Forms
      class IntentToFile < ClaimsApi::V2::Base
        version 'v2'

        resource 'forms/0966' do
          desc 'Submit a claim.'
          post '/' do
            raise 'NotImplemented'
          end
        end
      end
    end
  end
end
