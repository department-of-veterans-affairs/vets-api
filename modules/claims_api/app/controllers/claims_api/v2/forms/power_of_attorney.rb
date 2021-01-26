module ClaimsApi
  module V2
    module Forms
      class PowerOfAttorney < ClaimsApi::V2::Base
        resource :2122 do
          desc 'Submit claim.'
          post '/' do
            raise 'NotImplemented'
          end
        end
      end
    end
  end
end
