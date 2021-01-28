module ClaimsApi
  module V2
    module Forms
      class PowerOfAttorney < ClaimsApi::V2::Base
        version 'v2'

        resource 'forms/2122' do
          desc 'Submit a claim.'
          post '/' do
            raise 'NotImplemented'
          end
        end
      end
    end
  end
end
