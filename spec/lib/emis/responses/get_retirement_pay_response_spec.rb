# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_retirement_pay_response'
require 'lib/emis/support/emis_soap_response_examples'

describe EMIS::Responses::GetRetirementPayResponse do
  include_examples(
    'emis_soap_response',
    'spec/support/emis/getRetirementPayResponse.xml',
    EMIS::Responses::GetRetirementPayResponse
  )
end
