# frozen_string_literal: true

require_dependency 'claims_api/concerns/poa_verification'

module ClaimsApi
  module V1
    module Forms
      class PowerOfAttorneyController < ClaimsApi::BaseFormController
        include ClaimsApi::PoaVerification

        before_action { permit_scopes %w[claim.write] }
        before_action :validate_json_schema, only: %i[submit_form_2122]

        FORM_NUMBER = '2122'

        def submit_form_2122
        
        end
      end
    end
  end
end