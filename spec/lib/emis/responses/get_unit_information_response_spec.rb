# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_unit_information_response'
require 'lib/emis/support/emis_soap_response_examples'

describe EMIS::Responses::GetUnitInformationResponse do
  include_examples(
    'emis_soap_response',
    'spec/support/emis/getUnitInformationResponse.xml',
    EMIS::Responses::GetUnitInformationResponse
  )
end
