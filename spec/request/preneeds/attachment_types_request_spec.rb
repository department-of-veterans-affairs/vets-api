# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Preneeds Attachment Types Integration', type: :request do
  include SchemaMatchers

  it 'responds to GET #index' do
    VCR.use_cassette('preneeds/attachment_types/gets_a_list_of_attachment_types') do
      get '/v0/preneeds/attachment_types/'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('preneeds/attachment_types')
  end

  it 'responds to GET #index when camel-inlfected' do
    VCR.use_cassette('preneeds/attachment_types/gets_a_list_of_attachment_types') do
      get '/v0/preneeds/attachment_types/', headers: { 'X-Key-Inflection' => 'camel' }
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_camelized_response_schema('preneeds/attachment_types')
  end
end
