# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Messaging::Health::AllRecipients', type: :request do
  include SchemaMatchers

  let!(:user) { sis_user(:mhv, mhv_correlation_id: '123', mhv_account_type: 'Premium') }

  before do
    Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
  end

  after do
    Timecop.return
  end

  context 'when not authorized' do
    it 'responds with 403 error' do
      VCR.use_cassette('mobile/messages/session_error') do
        get '/mobile/v0/messaging/health/allrecipients', headers: sis_headers
      end
      expect(response).not_to be_successful
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when authorized' do
    before do
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end

    it 'responds to GET #all_recipients' do
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients') do
        get '/mobile/v0/messaging/health/allrecipients', headers: sis_headers
      end
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('all_triage_teams')
    end

    context 'when there are cached triage teams' do
      let(:params) { { useCache: true } }

      before do
        path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'all_triage_teams.json')
        data = Common::Collection.new(AllTriageTeams, data: JSON.parse(File.read(path)))
        AllTriageTeams.set_cached("#{user.uuid}-all-triage-teams", data)
      end

      it 'retrieve cached triage teams rather than hitting the service' do
        expect do
          get('/mobile/v0/messaging/health/allrecipients', headers: sis_headers, params:)
          expect(response).to be_successful
          expect(response.body).to be_a(String)
          parsed_response_contents = response.parsed_body['data']
          triage_team = parsed_response_contents.select { |entry| entry['id'] == '4399547' }[0]
          expect(triage_team.dig('attributes', 'name')).to eq('589GR Pharmacy Ask a pharmacist SLC10 JAMES, DON')
          expect(triage_team['type']).to eq('all_triage_teams')
          expect(response).to match_camelized_response_schema('all_triage_teams', { strict: false })
        end.to trigger_statsd_increment('mobile.sm.cache.hit', times: 1)
      end
    end
  end
end
