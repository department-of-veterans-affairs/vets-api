# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_separation_pay_response'
require 'lib/emis/support/emis_soap_response_examples'

describe EMIS::Responses::GetSeparationPayResponse do
  include_examples(
    'emis_soap_response',
    'spec/support/emis/getSeparationPayResponse.xml',
    EMIS::Responses::GetSeparationPayResponse
  )
end
