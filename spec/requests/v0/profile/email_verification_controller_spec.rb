# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email Verification HTTP API (unauthenticated)', type: :request do
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  before do
    allow(Flipper).to receive(:enabled?).with(:auth_exp_email_verification_enabled).and_return(true)
  end

  it 'returns 401 for status' do
    get('/v0/profile/email_verification/status', headers:)

    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns 401 for create' do
    post('/v0/profile/email_verification', headers:)

    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns 401 for verify' do
    get('/v0/profile/email_verification/verify', headers:)

    expect(response).to have_http_status(:unauthorized)
  end
end
