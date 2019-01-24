# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Return ICN for a User from MVI', type: :request, skip_emis: true do
  include SchemaMatchers
  let(:auth_headers) do
    {
      'apiKey' => 'saml-key',
      'x-va-ssn' => '333-99-9999',
      'x-va-first-name' => 'Edward',
      'x-va-middle-name' => 'John',
      'x-va-last-name' => 'Paget',
      'x-va-dob' => '1/23/1990',
      'x-va-gender' => 'male'
    }
  end

  it 'should return the icn data for a user' do
    get '/internal/auth/v0/mvi-user', { loa: { current: 3, highest: 3 }, user_email: 'test123@example.com' }, auth_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to be_a(String)
    expect(JSON.parse(response.body)['data']['attributes'].keys).to eq(['icn'])
    expect(JSON.parse(response.body)['data']['attributes'].values).to_not eq([nil])
  end

  it 'should return an error if icn is missing' do
    get '/internal/auth/v0/mvi-user', { loa: { current: 1, highest: 1 }, user_email: 'test123@example.com'} }, auth_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to be_a(String)
    expect(JSON.parse(response.body)['data']['errors'].keys).to eq(['icn'])
    expect(JSON.parse(response.body)['data']['errors'].values).to eq(['could not locate ICN'])
  end
end
