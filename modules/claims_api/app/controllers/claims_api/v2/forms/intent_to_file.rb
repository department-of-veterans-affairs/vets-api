module ClaimsApi
  module V2
    module Forms
      class IntentToFile < ClaimsApi::V2::Base
        version 'v2'
        
        resource '0966' do
          desc 'Submit claim.'
          post '/' do
            raise 'NotImplemented'
          end
        end
      end
    end
  end
end
