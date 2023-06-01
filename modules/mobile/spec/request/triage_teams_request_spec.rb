# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/helpers/mobile_sm_client_helper'

RSpec.describe 'Mobile Triage Teams Integration', type: :request do
  include Mobile::MessagingClientHelper
  include SchemaMatchers

  let(:va_patient) { true }

  before do
    allow_any_instance_of(MHVAccountTypeService).to receive(:mhv_account_type).and_return(mhv_account_type)
    allow(Mobile::V0::Messaging::Client).to receive(:new).and_return(authenticated_client)
    iam_sign_in(build(:iam_user, iam_mhv_id: '123'))
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    it 'responds to GET #index' do
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_triage_team_recipients') do
        get '/mobile/v0/messaging/health/recipients', headers: iam_headers
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('triage_teams')
    end

    context 'when there are cached triage teams' do
      let(:user) { FactoryBot.build(:iam_user) }
      let(:params) { { useCache: true } }

      before do
        path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'triage_teams.json')
        data = Common::Collection.new(TriageTeam, data: JSON.parse(File.read(path)))
        TriageTeam.set_cached("#{user.uuid}-triage-teams", data)
      end

      it 'retrieve cached triage teams rather than hitting the service' do
        expect do
          get('/mobile/v0/messaging/health/recipients', headers: iam_headers, params:)
          expect(response).to be_successful
          expect(response.body).to be_a(String)
          parsed_response_contents = response.parsed_body['data']
          triage_team = parsed_response_contents.select { |entry| entry['id'] == '153463' }[0]
          expect(triage_team.dig('attributes', 'name')).to eq('Automation Triage')
          expect(triage_team['type']).to eq('triage_teams')
          expect(response).to match_camelized_response_schema('triage_teams')
        end.to trigger_statsd_increment('mobile.sm.cache.hit', times: 1)
      end
    end
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    it 'is not authorized' do
      get '/mobile/v0/messaging/health/recipients', headers: iam_headers
      expect(response).not_to be_successful
      expect(response.status).to eq(403)
    end
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    it 'is not authorized' do
      get '/mobile/v0/messaging/health/recipients', headers: iam_headers
      expect(response).not_to be_successful
      expect(response.status).to eq(403)
    end
  end
end
