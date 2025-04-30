# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Messaging::Health::Recipients', type: :request do
  include SchemaMatchers

  let!(:user) { sis_user(:mhv, mhv_correlation_id: '123', mhv_account_type: 'Premium') }

  before do
    Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
  end

  after do
    Timecop.return
  end

  context 'with mobile_get_expanded_triage_teams feature flag disabled' do
    before do
      allow(Flipper).to receive(:enabled?).and_call_original
      allow(Flipper).to receive(:enabled?).with(:mobile_get_expanded_triage_teams, anything).and_return(false)
    end

    context 'when not authorized' do
      it 'responds with 403 error' do
        VCR.use_cassette('mobile/messages/session_error') do
          get '/mobile/v0/messaging/health/recipients', headers: sis_headers
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

      it 'responds to GET #index' do
        VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_triage_team_recipients') do
          get '/mobile/v0/messaging/health/recipients', headers: sis_headers
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('triage_teams')
      end

      context 'when there are cached triage teams' do
        let(:params) { { useCache: true } }

        before do
          path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'triage_teams.json')
          data = Common::Collection.new(TriageTeam, data: JSON.parse(File.read(path)))
          TriageTeam.set_cached("#{user.uuid}-triage-teams", data)
        end

        it 'retrieve cached triage teams rather than hitting the service' do
          expect do
            get('/mobile/v0/messaging/health/recipients', headers: sis_headers, params:)
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
  end

  context 'with mobile_get_expanded_triage_teams feature flag enabled' do
    before do
      VCR.insert_cassette('sm_client/session')
      allow(Flipper).to receive(:enabled?).and_call_original
      allow(Flipper).to receive(:enabled?).with(:mobile_get_expanded_triage_teams, anything).and_return(true)
    end

    after do
      VCR.eject_cassette
    end

    it 'responds to GET #index with properly formatted triage teams' do
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients') do
        get '/mobile/v0/messaging/health/recipients', headers: sis_headers
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)

      parsed_response = response.parsed_body
      expect(parsed_response).to have_key('data')

      data = parsed_response['data']
      expect(data).to be_an(Array)
      expect(data).not_to be_empty

      # Verify structure of a triage team entry
      team = data.first
      expect(team).to have_key('id')
      expect(team).to have_key('type')
      expect(team).to have_key('attributes')
      expect(team['type']).to eq('all_triage_teams')

      # Verify specific attributes from the VCR cassette
      attributes = team['attributes']
      expect(attributes).to include(
        'name' => '589GR Pharmacy Ask a pharmacist SLC10 JAMES, DON',
        'stationNumber' => '979',
        'blockedStatus' => false,
        'preferredTeam' => true
      )
    end

    it 'supports requires_oh parameter for retrieving all triage teams with OH flag' do
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients_require_oh') do
        get '/mobile/v0/messaging/health/recipients', headers: sis_headers, params: { requires_oh: '1' }
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)

      parsed_response = response.parsed_body
      expect(parsed_response).to have_key('data')

      data = parsed_response['data']
      expect(data).to be_an(Array)
      expect(data).not_to be_empty

      # Verify the OH flag was correctly passed by checking specific attributes
      # that should be present in the response
      team = data.first
      expect(team).to have_key('attributes')
      attributes = team['attributes']

      expect(attributes).to include(
        'name' => '589GR Pharmacy Ask a pharmacist SLC10 JAMES, DON',
        'stationNumber' => '979'
      )

      # Additional verification for any OH-specific fields if applicable
      expect(attributes).to have_key('preferredTeam')
    end

    context 'when there are cached all triage teams' do
      let(:params) { { useCache: true } }

      before do
        all_triage_team = AllTriageTeams.new(
          triage_team_id: 4_399_547,
          name: '589GR Pharmacy Ask a pharmacist SLC10 JAMES, DON',
          station_number: '979',
          blocked_status: false,
          preferred_team: true
        )
        data = Common::Collection.new(AllTriageTeams, data: [all_triage_team])
        AllTriageTeams.set_cached("#{user.uuid}-all-triage-teams", data)
      end

      it 'retrieves cached all triage teams rather than hitting the service' do
        expect do
          get('/mobile/v0/messaging/health/recipients', headers: sis_headers, params:)
          expect(response).to be_successful
          expect(response.body).to be_a(String)
          parsed_response_contents = response.parsed_body['data']
          expect(parsed_response_contents.length).to eq(1)
          triage_team = parsed_response_contents[0]
          expect(triage_team.dig('attributes', 'name')).to eq('589GR Pharmacy Ask a pharmacist SLC10 JAMES, DON')
          expect(triage_team.dig('attributes', 'stationNumber')).to eq('979')
        end.to trigger_statsd_increment('mobile.sm.cache.hit', times: 1)
      end
    end
  end
end
