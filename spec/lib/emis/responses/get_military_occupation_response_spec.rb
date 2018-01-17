# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_military_occupation_response'
require 'lib/emis/support/emis_soap_response_examples'

describe EMIS::Responses::GetMilitaryOccupationResponse do
  include_examples(
    'emis_soap_response',
    'spec/support/emis/getMilitaryOccupationResponse.xml',
    EMIS::Responses::GetMilitaryOccupationResponse
  )
end
