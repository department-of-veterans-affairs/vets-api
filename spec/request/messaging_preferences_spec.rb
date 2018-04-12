# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'Messaging Preferences Integration', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient: va_patient, mhv_account_type: mhv_account_type) }

  before(:each) do
    allow(SM::Client).to receive(:new).and_return(authenticated_client)
    use_authenticated_current_user(current_user: current_user)
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }
    before(:each) { get'/v0/messaging/health/preferences' }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for user that is not a va patient', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }
    before(:each) { get'/v0/messaging/health/preferences' }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for user that is not a va patient', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    context 'not a va patient' do
      before(:each) { get'/v0/messaging/health/preferences' }
      let(:va_patient) { false }

      include_examples 'for user that is not a va patient', authorized: false, message: 'You do not have access to messaging'
    end

    it 'responds to GET #show of preferences' do
      VCR.use_cassette('sm_client/preferences/fetches_email_settings_for_notifications') do
        get '/v0/messaging/health/preferences'
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      attrs = JSON.parse(response.body)['data']['attributes']
      expect(attrs['email_address']).to eq('muazzam.khan@va.gov')
      expect(attrs['frequency']).to eq('daily')
    end

    it 'responds to PUT #update of preferences' do
      VCR.use_cassette('sm_client/preferences/sets_the_email_notification_settings', record: :none) do
        params = { email_address: 'kamyar.karshenas@va.gov',
                   frequency: 'none' }
        put '/v0/messaging/health/preferences', params
      end

      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['data']['id'])
        .to eq('17126b0821ad0472ae11944e9861f82d6bdd17801433e200e6a760148a4866c3')
      expect(JSON.parse(response.body)['data']['attributes'])
        .to eq('email_address' => 'kamyar.karshenas@va.gov', 'frequency' => 'none')
    end

    it 'requires all parameters for update' do
      VCR.use_cassette('sm_client/preferences/sets_the_email_notification_settings', record: :none) do
        params = { email_address: 'kamyar.karshenas@va.gov' }
        put '/v0/messaging/health/preferences', params
      end

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects unknown frequency parameters' do
      VCR.use_cassette('sm_client/preferences/sets_the_email_notification_settings', record: :none) do
        params = { email_address: 'kamyar.karshenas@va.gov',
                   frequency: 'hourly' }
        put '/v0/messaging/health/preferences', params
      end

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns a custom exception mapped from i18n when email contains spaces' do
      VCR.use_cassette('sm_client/preferences/raises_a_backend_service_exception_when_email_includes_spaces') do
        params = { email_address: 'kamyar karshenas@va.gov',
                   frequency: 'daily' }
        put '/v0/messaging/health/preferences', params
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].first['code']).to eq('SM152')
    end
  end
end
