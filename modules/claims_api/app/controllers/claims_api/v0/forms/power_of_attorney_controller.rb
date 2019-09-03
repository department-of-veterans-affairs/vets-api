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
        
        end
      end
    end
  end
end