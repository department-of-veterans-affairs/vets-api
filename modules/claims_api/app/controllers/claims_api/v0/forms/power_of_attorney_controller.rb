# frozen_string_literal: true

require_dependency 'claims_api/base_form_controller'
require 'jsonapi/parser'

module ClaimsApi
  module V0
    module Forms
      class PowerOfAttorneyController < ClaimsApi::BaseFormController
        FORM_NUMBER = '2122'

        skip_before_action(:authenticate)
        before_action :validate_json_schema, only: %i[submit_form_2122]

        def submit_form_2122
          power_of_attorney = ClaimsApi::PowerOfAttorney.create(
            status: 'submitted',
            auth_headers: auth_headers,
            form_data: form_attributes,
            source: request.headers['X-Consumer-Username']
          )
          power_of_attorney = ClaimsApi::PowerOfAttorney.find_by(md5: power_of_attorney.md5) unless power_of_attorney.id

          render json: power_of_attorney, serializer: ClaimsApi::PowerOfAttorneySerializer
        end

        def status_2122; end
      end
    end
  end
end
