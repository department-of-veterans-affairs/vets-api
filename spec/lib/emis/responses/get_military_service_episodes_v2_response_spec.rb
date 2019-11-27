# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_military_service_episodes_v2_response'
require 'lib/emis/support/emis_soap_response_examples'

describe EMIS::Responses::GetMilitaryServiceEpisodesV2Response do
  include_examples(
    'emis_soap_response',
    'spec/support/emis/getMilitaryServiceEpisodesV2Response.xml',
    EMIS::Responses::GetMilitaryServiceEpisodesV2Response
  )
end
