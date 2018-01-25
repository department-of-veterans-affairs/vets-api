# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_military_service_eligibility_info_response'
require 'lib/emis/support/emis_soap_response_examples'

describe EMIS::Responses::GetMilitaryServiceEligibilityInfoResponse do
  include_examples(
    'emis_soap_response',
    'spec/support/emis/getMilitaryServiceEligibilityInfoResponse.xml',
    EMIS::Responses::GetMilitaryServiceEligibilityInfoResponse
  )
end
