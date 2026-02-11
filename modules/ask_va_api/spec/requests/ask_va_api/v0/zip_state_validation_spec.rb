# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AskVAApi::V0::ZipStateValidation', type: :request do
  let(:path) { '/ask_va_api/v0/zip_state_validation' }

  before do
    host! 'localhost'
    ca_state_id = 9_001_001
    nv_state_id = 9_001_002

    StdState.create!(
      id: ca_state_id,
      name: 'California',
      postal_name: 'CA',
      fips_code: 6,
      country_id: 1_006_840,
      version: 0,
      created: Time.zone.parse('2007-05-07 10:19:56 UTC'),
      created_by: 'Test Seed'
    )

    StdState.create!(
      id: nv_state_id,
      name: 'Nevada',
      postal_name: 'NV',
      fips_code: 32,
      country_id: 1_006_840,
      version: 0,
      created: Time.zone.parse('2007-05-07 10:19:56 UTC'),
      created_by: 'Test Seed'
    )

    # 94107 belongs to CA
    StdZipcode.create!(
      id: 8_001_001,
      zip_code: '94107',
      zip_classification_id: 1_100_003,
      preferred_zip_place_id: 1_160_001,
      state_id: ca_state_id,
      county_number: 103,
      version: 0,
      created: Time.zone.parse('2007-05-07 10:23:06 UTC'),
      created_by: 'Test Seed'
    )
  end

  it 'returns valid true when zip belongs to state' do
    post path, params: { zip_code: '94107', state_code: 'CA' }, as: :json

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)

    expect(body).to include(
      'valid' => true,
      'error_code' => nil,
      'error_message' => nil
    )
  end

  it 'returns ZIP_STATE_MISMATCH when zip does not belong to state' do
    post path, params: { zip_code: '94107', state_code: 'NV' }, as: :json

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)

    expect(body['valid']).to be(false)
    expect(body['error_code']).to eq('ZIP_STATE_MISMATCH')
    expect(body['error_message']).to be_present
  end

  it 'returns INVALID_ZIP when zip is not 5 digits after normalization' do
    post path, params: { zip_code: '9410', state_code: 'CA' }, as: :json

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)

    expect(body['valid']).to be(false)
    expect(body['error_code']).to eq('INVALID_ZIP')
    expect(body['error_message']).to be_present
  end

  it 'normalizes 9-digit zip+4 to 5 digits' do
    post path, params: { zip_code: '94107-1234', state_code: 'CA' }, as: :json

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)

    expect(body['valid']).to be(true)
  end

  it 'returns INVALID_ZIP when zip_code is missing' do
    post path, params: { state_code: 'CA' }, as: :json

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)

    expect(body['valid']).to be(false)
    expect(body['error_code']).to eq('INVALID_ZIP')
    expect(body['error_message']).to be_present
  end

  it 'returns STATE_NOT_FOUND when state_code is missing' do
    post path, params: { zip_code: '94107' }, as: :json

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)

    expect(body['valid']).to be(false)
    expect(body['error_code']).to eq('STATE_NOT_FOUND')
    expect(body['error_message']).to be_present
  end
end
