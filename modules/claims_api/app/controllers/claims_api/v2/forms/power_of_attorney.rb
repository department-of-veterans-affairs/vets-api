module ClaimsApi
  module V2
    module Forms
      class PowerOfAttorney < ClaimsApi::V2::Base
        version 'v2'

        resource '2122' do
          desc 'Submit claim.'
          post '/' do
            raise 'NotImplemented'
          end
        end
      end
    end
  end
end
