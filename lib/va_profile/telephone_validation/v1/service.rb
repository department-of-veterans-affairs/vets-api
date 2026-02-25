# frozen_string_literal: true

require 'va_profile/service'
require 'va_profile/telephone_validation/v1/configuration'

module VAProfile
  module TelephoneValidation
    module V1
      class Service < VAProfile::Service
        configuration VAProfile::TelephoneValidation::V1::Configuration

        def initialize(user = 'telephone_validation')
          super(user)
        end

        def validate(telephone_hash)
          body = { telephone: telephone_hash }.to_json
          perform(:post, 'validate', body, headers)
        end

        private

        def headers
          { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
        end
      end
    end
  end
end