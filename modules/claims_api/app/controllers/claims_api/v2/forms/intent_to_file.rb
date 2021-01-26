module ClaimsApi
  module V2
    module Forms
      class IntentToFile < ClaimsApi::V2::Base
        resource :0966 do
          desc 'Submit claim.'
          post '/' do
            raise 'NotImplemented'
          end
        end
      end
    end
  end
end
