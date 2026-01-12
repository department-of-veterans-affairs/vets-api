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

    it 'filters out teams with blocked_status == true' do
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients_include_blocked') do
        get '/mobile/v0/messaging/health/allrecipients', headers: sis_headers
      end
      expect(response).to be_successful
      expect(response.parsed_body['data'].count).to eq(1)
      expect(response).to match_camelized_response_schema('all_triage_teams')
    end

    it 'responds to GET #all_recipients with requires_oh flipper enabled and returns correct care systems' do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_secure_messaging_cerner_pilot, anything)
        .and_return(true)
      VCR.use_cassette('sm_client/session_require_oh') do
        VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients_require_oh') do
          get '/mobile/v0/messaging/health/allrecipients', headers: sis_headers
        end
      end

      parsed_response_meta = response.parsed_body['meta']
      care_systems = parsed_response_meta['careSystems']
      expect(care_systems.length).to be(3)
      # MyHealth::FacilitiesHelper converts non-prod station numbers:
      # 979 -> 552, 989 -> 442, others unchanged
      # health_care_system_name comes from API response or COMPLICATED_SYSTEMS lookup
      expect(care_systems.map { |cs| cs['stationNumber'] }).to contain_exactly('977', '978', '552')
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('all_triage_teams', { strict: false })
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

    context 'when there are multiple triage groups at the same care system' do
      let(:params) { { useCache: true } }

      before do
        path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures',
                               'all_triage_teams_with_duplicates.json')
        data = Common::Collection.new(AllTriageTeams, data: JSON.parse(File.read(path)))
        AllTriageTeams.set_cached("#{user.uuid}-all-triage-teams", data)
      end

      it 'returns a list of the name and station number for each unique care system with correct healthcare names' do
        get('/mobile/v0/messaging/health/allrecipients', headers: sis_headers, params:)

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        parsed_response_meta = response.parsed_body['meta']
        care_systems = parsed_response_meta['careSystems']
        expect(care_systems.length).to be(10)
        # Complex systems get correct healthcare system names via MyHealth::FacilitiesHelper
        # Station 612 maps to 612A4 and gets COMPLICATED_SYSTEMS name
        care_system_map = care_systems.to_h { |cs| [cs['stationNumber'], cs['healthCareSystemName']] }
        expect(care_system_map['612A4']).to eq('VA Northern California (multiple facilities)')
        expect(care_system_map['528']).to eq('VA New York state health care (multiple facilities)')
        expect(care_system_map['589']).to eq('VA Kansas and Missouri health care (multiple facilities)')
        expect(care_system_map['620']).to eq('VA Hudson Valley New York health care (multiple facilities)')
        expect(care_system_map['626']).to eq('VA Tennessee health care (multiple facilities)')
        expect(care_system_map['636']).to eq('VA Nebraska and Iowa health care (multiple facilities)')
        expect(care_system_map['657']).to eq('VA Missouri and Illinois health care (multiple facilities)')
      end
    end
  end
end
