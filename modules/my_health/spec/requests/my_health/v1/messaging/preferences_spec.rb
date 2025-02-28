# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::Messaging::Preferences', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:current_user) { build(:user, :mhv) }

  before do
    sign_in_as(current_user)
    Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
  end

  after do
    Timecop.return
  end

  context 'when NOT authorized' do
    before do
      VCR.insert_cassette('sm_client/session_error')
      get '/my_health/v1/messaging/preferences'
    end

    after do
      VCR.eject_cassette
    end

    include_examples 'for user account level', message: 'You do not have access to messaging'
  end

  context 'when authorized' do
    before do
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end

    it 'responds to GET #show of preferences' do
      VCR.use_cassette('sm_client/preferences/fetches_email_settings_for_notifications') do
        get '/my_health/v1/messaging/preferences'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      attrs = JSON.parse(response.body)['data']['attributes']
      expect(attrs['email_address']).to eq('muazzam.khan@va.gov')
      expect(attrs['frequency']).to eq('daily')
    end

    it 'responds to PUT #update of preferences' do
      VCR.use_cassette('sm_client/preferences/sets_the_email_notification_settings', record: :none) do
        params = { email_address: 'kamyar.karshenas@va.gov',
                   frequency: 'none' }
        put '/my_health/v1/messaging/preferences', params:
      end

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']['id'])
        .to eq('17126b0821ad0472ae11944e9861f82d6bdd17801433e200e6a760148a4866c3')
      expect(JSON.parse(response.body)['data']['attributes'])
        .to eq('email_address' => 'kamyar.karshenas@va.gov', 'frequency' => 'none')
    end

    it 'requires all parameters for update' do
      VCR.use_cassette('sm_client/preferences/sets_the_email_notification_settings', record: :none) do
        params = { email_address: 'kamyar.karshenas@va.gov' }
        put '/my_health/v1/messaging/preferences', params:
      end

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects unknown frequency parameters' do
      VCR.use_cassette('sm_client/preferences/sets_the_email_notification_settings', record: :none) do
        params = { email_address: 'kamyar.karshenas@va.gov',
                   frequency: 'hourly' }
        put '/my_health/v1/messaging/preferences', params:
      end

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns a custom exception mapped from i18n when email contains spaces' do
      VCR.use_cassette('sm_client/preferences/raises_a_backend_service_exception_when_email_includes_spaces') do
        params = { email_address: 'kamyar karshenas@va.gov',
                   frequency: 'daily' }
        put '/my_health/v1/messaging/preferences', params:
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].first['code']).to eq('SM152')
    end

    it 'responds to POST #update_triage_team_preferences' do
      VCR.use_cassette('sm_client/preferences/updates_triage_team_preferences') do
        params = { updated_triage_teams: [{ triage_team_id: 1_013_155, preferred_team: true }] }
        post '/my_health/v1/messaging/preferences/recipients', params:
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('200')
    end

    it 'POST #update_triage_team_preferences requires at least one triage team to include preferredTeam true' do
      params = { updated_triage_teams: [{ triage_team_id: 1_013_155, preferred_team: false }] }
      post('/my_health/v1/messaging/preferences/recipients', params:)

      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('Invalid input: updated_triage_teams cannot be empty or have all preferred_team values set to false')
    end

    it 'POST #update_triage_team_preferences requires a valid triage team' do
      VCR.use_cassette('sm_client/preferences/updates_triage_team_preferences_error_invalid_triage_team') do
        params = { updated_triage_teams: [{ triage_team_id: 1_013_155_234, preferred_team: true }] }
        post '/my_health/v1/messaging/preferences/recipients', params:
      end
      expect(JSON.parse(response.body)['errors'].first['code']).to eq('SM99')
    end

    it 'GET #signature' do
      VCR.use_cassette('sm_client/preferences/fetches_the_signature_preferences') do
        get '/my_health/v1/messaging/preferences/signature'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      attributes = JSON.parse(response.body)['data']['attributes']
      expect(attributes['include_signature']).to be(true)
      expect(attributes['signature_name']).to eq('Test Mark')
      expect(attributes['signature_title']).to eq('Test Title API')
    end

    it 'GET #signature when include_signature is set to false' do
      VCR.use_cassette('sm_client/preferences/fetches_the_signature_preferences_include_signature_false') do
        get '/my_health/v1/messaging/preferences/signature'
      end
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      attributes = JSON.parse(response.body)['data']['attributes']

      # vets-api returns include_signature as true
      # as long as signature_name and signature_title are not empty
      expect(attributes['include_signature']).to be(true)
      expect(attributes['signature_name']).to eq('Test Mark')
      expect(attributes['signature_title']).to eq('Test Title API')
    end

    it 'POST #update_signature' do
      VCR.use_cassette('sm_client/preferences/sets_the_signature_preferences') do
        params = {
          messaging_preference: {
            signature_name: 'Test Mark',
            include_signature: true,
            signature_title: 'Test Title API'
          }
        }
        post '/my_health/v1/messaging/preferences/signature', params:
      end

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']['attributes'])
        .to eq('include_signature' => true, 'signature_name' => 'Test Mark', 'signature_title' => 'Test Title API')
    end

    it 'POST #update_signature when include_signature is set to false' do
      VCR.use_cassette('sm_client/preferences/sets_the_signature_preferences_include_signature_false') do
        params = {
          messaging_preference: {
            signature_name: 'Test Mark',
            include_signature: false,
            signature_title: 'Test Title API'
          }
        }
        post '/my_health/v1/messaging/preferences/signature', params:
      end

      expect(response).to have_http_status(:ok)
      # vets-api returns include_signature as true
      # as long as signature_name and signature_title are not empty
      expect(JSON.parse(response.body)['data']['attributes'])
        .to eq('include_signature' => true, 'signature_name' => 'Test Mark', 'signature_title' => 'Test Title API')
    end

    it 'handles missing parameters for POST #update_signature' do
      VCR.use_cassette('sm_client/preferences/missing_params_updating_the_signature_preferences') do
        params = {
          messaging_preference: {
            include_signature: true
          }
        }
        post '/my_health/v1/messaging/preferences/signature', params:
      end

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['errors'][0]['detail']).to eq('Email Signature Name and Title is required')
      expect(JSON.parse(response.body)['errors'][0]['code']).to eq('SM154')
    end

    it 'handles missing signature_name and signature_title parameters for POST #update_signature' do
      VCR.use_cassette('sm_client/preferences/sets_the_signature_preferences_exclude_name_and_title') do
        params = {
          messaging_preference: {
            include_signature: true
          }
        }
        post '/my_health/v1/messaging/preferences/signature', params:
      end
      expect(JSON.parse(response.body)['data']['attributes'])
        .to eq('include_signature' => false, 'signature_name' => nil, 'signature_title' => nil)
    end
  end
end
