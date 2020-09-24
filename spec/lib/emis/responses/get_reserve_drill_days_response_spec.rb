# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_reserve_drill_days_response'
require 'lib/emis/support/emis_soap_response_examples'

describe EMIS::Responses::GetReserveDrillDaysResponse do
  include_examples(
    'emis_soap_response',
    'spec/support/emis/getReserveDrillDaysResponse.xml',
    EMIS::Responses::GetReserveDrillDaysResponse
  )
end
