# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_retirement_response'
require 'lib/emis/support/emis_soap_response_examples'

describe EMIS::Responses::GetRetirementResponse do
  include_examples(
    'emis_soap_response',
    'spec/support/emis/getRetirementResponse.xml',
    EMIS::Responses::GetRetirementResponse
  )
end
