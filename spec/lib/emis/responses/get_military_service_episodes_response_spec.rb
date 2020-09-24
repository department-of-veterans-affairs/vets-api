# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_military_service_episodes_response'
require 'lib/emis/support/emis_soap_response_examples'

describe EMIS::Responses::GetMilitaryServiceEpisodesResponse do
  include_examples(
    'emis_soap_response',
    'spec/support/emis/getMilitaryServiceEpisodesResponse.xml',
    EMIS::Responses::GetMilitaryServiceEpisodesResponse
  )
end
