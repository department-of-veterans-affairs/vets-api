# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_military_service_episodes_response_v2'
require 'lib/emis/support/emis_soap_response_examples'

describe EMIS::Responses::GetMilitaryServiceEpisodesResponseV2 do
  include_examples(
    'emis_soap_response',
    'spec/support/emis/getMilitaryServiceEpisodesResponseV2.xml',
    EMIS::Responses::GetMilitaryServiceEpisodesResponseV2
  )
end
