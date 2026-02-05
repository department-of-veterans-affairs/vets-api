# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'
require 'sm/client'

RSpec.describe 'Mobile::V0::Messaging::Health::AllRecipients', type: :request do
  include SchemaMatchers

  let!(:user) { sis_user(:mhv, mhv_correlation_id: '123', mhv_account_type: 'Premium') }
  let(:care_systems_stub) { [{ station_number: '977', health_care_system_name: 'Manila VA Clinic' }] }

  before do
    Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
    allow(Flipper).to receive(:enabled?)
      .with(:mhv_secure_messaging_612_care_systems_fix, anything)
      .and_return(false)
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
      allow_any_instance_of(SM::Client).to receive(:get_triage_teams_station_numbers).and_return([])
    end

    after do
      VCR.eject_cassette
    end

    it 'responds to GET #all_recipients' do
      allow_any_instance_of(Mobile::V0::RecipientsController).to receive(:get_unique_care_systems).and_return(
        care_systems_stub
      )
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients') do
        get '/mobile/v0/messaging/health/allrecipients', headers: sis_headers
      end
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('all_triage_teams')
    end

    it 'filters out teams with blocked_status == true' do
      allow_any_instance_of(Mobile::V0::RecipientsController).to receive(:get_unique_care_systems).and_return(
        care_systems_stub
      )
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients_include_blocked') do
        get '/mobile/v0/messaging/health/allrecipients', headers: sis_headers
      end
      expect(response).to be_successful
      expect(response.parsed_body['data'].count).to eq(1)
      expect(response).to match_camelized_response_schema('all_triage_teams')
    end

    it 'responds to GET #index with requires_oh flipper and 612 flipper enabled and returns correct care systems' do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_secure_messaging_cerner_pilot, anything)
        .and_return(true)
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_secure_messaging_612_care_systems_fix, anything)
        .and_return(true)
      VCR.use_cassette('sm_client/session_require_oh') do
        VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients_require_oh') do
          VCR.use_cassette('mobile/lighthouse_facilities/200_facilities_977_978_979') do
            get '/mobile/v0/messaging/health/allrecipients', headers: sis_headers
          end
        end
      end

      parsed_response_meta = response.parsed_body['meta']
      care_systems = parsed_response_meta['careSystems']
      expect(care_systems.length).to be(3)
      expect(care_systems[0]['healthCareSystemName']).to eq('Manila VA Clinic')
      expect(care_systems[1]['healthCareSystemName']).to eq('978')
      expect(care_systems[2]['healthCareSystemName']).to eq('Chalmers P. Wylie Veterans Outpatient Clinic')
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('all_triage_teams', { strict: false })
    end

    it 'returns successfully with station numbers as fallback when Lighthouse Facilities API fails' do
      allow(StatsD).to receive(:increment)
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_secure_messaging_cerner_pilot, anything)
        .and_return(true)
      VCR.use_cassette('sm_client/session_require_oh') do
        VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients_require_oh') do
          VCR.use_cassette('mobile/lighthouse_facilities/500_facilities_error') do
            get '/mobile/v0/messaging/health/allrecipients', headers: sis_headers
          end
        end
      end

      expect(response).to be_successful
      expect(StatsD).to have_received(:increment).with('mobile.sm.allrecipients.facilities_lookup.failure')
      parsed_response_meta = response.parsed_body['meta']
      care_systems = parsed_response_meta['careSystems']
      expect(care_systems.length).to be(3)
      # All health_care_system_name values should fall back to station_number
      expect(care_systems[0]['healthCareSystemName']).to eq('977')
      expect(care_systems[0]['stationNumber']).to eq('977')
      expect(care_systems[1]['healthCareSystemName']).to eq('978')
      expect(care_systems[1]['stationNumber']).to eq('978')
      expect(care_systems[2]['healthCareSystemName']).to eq('979')
      expect(care_systems[2]['stationNumber']).to eq('979')
      expect(response).to match_camelized_response_schema('all_triage_teams', { strict: false })
    end

    it 'responds to GET #index with requires_oh flipper enabled but 612 disabled and returns correct care systems' do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_secure_messaging_cerner_pilot, anything)
        .and_return(true)
      VCR.use_cassette('sm_client/session_require_oh') do
        VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients_require_oh') do
          VCR.use_cassette('mobile/lighthouse_facilities/200_facilities_977_978_979') do
            get '/mobile/v0/messaging/health/allrecipients', headers: sis_headers
          end
        end
      end

      parsed_response_meta = response.parsed_body['meta']
      care_systems = parsed_response_meta['careSystems']
      expect(care_systems.length).to be(3)
      expect(care_systems[0]['healthCareSystemName']).to eq('Manila VA Clinic')
      expect(care_systems[1]['healthCareSystemName']).to eq('978')
      expect(care_systems[2]['healthCareSystemName']).to eq('Chalmers P. Wylie Veterans Outpatient Clinic')
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('all_triage_teams', { strict: false })
    end

    context 'when stubbing get_all_triage_teams' do
      let(:params) { { useCache: true } }

      before do
        path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'all_triage_teams.json')
        data = Vets::Collection.new(JSON.parse(File.read(path)), AllTriageTeams)
        allow_any_instance_of(SM::Client).to receive(:get_all_triage_teams).and_return(data)
      end

      it 'retrieves triage teams from the stubbed client' do
        allow_any_instance_of(Mobile::V0::RecipientsController).to receive(:get_unique_care_systems).and_return(
          care_systems_stub
        )
        get('/mobile/v0/messaging/health/allrecipients', headers: sis_headers, params:)
        expect(response).to be_successful
        expect(response.body).to be_a(String)
        parsed_response_contents = response.parsed_body['data']
        triage_team = parsed_response_contents.select { |entry| entry['id'] == '4399547' }[0]
        expect(triage_team.dig('attributes', 'name')).to eq('589GR Pharmacy Ask a pharmacist SLC10 JAMES, DON')
        expect(triage_team['type']).to eq('all_triage_teams')
        expect(response).to match_camelized_response_schema('all_triage_teams', { strict: false })
      end
    end

    context 'when there are multiple triage groups at the same care system' do
      let(:params) { { useCache: true } }

      before do
        path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures',
                               'all_triage_teams_with_duplicates.json')
        data = Vets::Collection.new(JSON.parse(File.read(path)), AllTriageTeams)
        allow_any_instance_of(SM::Client).to receive(:get_all_triage_teams).and_return(data)
      end

      it 'returns a list of the name and station number for each unique care system in meta with 612 off' do
        VCR.use_cassette('mobile/lighthouse_facilities/200_hardcoded_facilities') do
          get('/mobile/v0/messaging/health/allrecipients', headers: sis_headers, params:)
        end
        expect(response).to be_successful
        expect(response.body).to be_a(String)
        parsed_response_meta = response.parsed_body['meta']
        care_systems = parsed_response_meta['careSystems']
        expect(care_systems.length).to be(10)
        expect(care_systems[0]['healthCareSystemName']).to eq('Manila VA Clinic')
        expect(care_systems[1]['healthCareSystemName']).to eq('612')
        expect(care_systems[2]['healthCareSystemName']).to eq('978')
        expect(care_systems[3]['healthCareSystemName']).to eq('Chalmers P. Wylie Veterans Outpatient Clinic')
        expect(care_systems[4]['healthCareSystemName']).to eq('528')
        expect(care_systems[5]['healthCareSystemName']).to eq('620')
        expect(care_systems[6]['healthCareSystemName']).to eq('657')
        expect(care_systems[7]['healthCareSystemName']).to eq('589')
        expect(care_systems[8]['healthCareSystemName']).to eq('626')
        expect(care_systems[9]['healthCareSystemName']).to eq('636')
      end

      it 'returns a list of the name and station number for each unique care system in meta with 612 on' do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_secure_messaging_612_care_systems_fix, anything)
          .and_return(true)

        VCR.use_cassette('mobile/lighthouse_facilities/200_facilities_977_978_979') do
          get('/mobile/v0/messaging/health/allrecipients', headers: sis_headers, params:)
        end
        expect(response).to be_successful
        expect(response.body).to be_a(String)
        parsed_response_meta = response.parsed_body['meta']
        care_systems = parsed_response_meta['careSystems']
        expect(care_systems.length).to be(10)
        # rubocop:disable Layout/LineLength
        expect(care_systems[0]['healthCareSystemName']).to eq('Manila VA Clinic')
        expect(care_systems[1]['healthCareSystemName']).to eq('978')
        expect(care_systems[2]['healthCareSystemName']).to eq('Chalmers P. Wylie Veterans Outpatient Clinic')
        expect(care_systems[3]['healthCareSystemName']).to eq('VA New York State Healthcare (multiple facilities)')
        expect(care_systems[4]['healthCareSystemName']).to eq('VA Kansas and Missouri Healthcare (multiple facilities)')
        expect(care_systems[5]['healthCareSystemName']).to eq('VA Hudson Valley New York Healthcare (multiple facilities)')
        expect(care_systems[6]['healthCareSystemName']).to eq('VA Tennessee Healthcare (multiple facilities)')
        expect(care_systems[7]['healthCareSystemName']).to eq('VA Nebraska and Iowa Healthcare (multiple facilities)')
        expect(care_systems[8]['healthCareSystemName']).to eq('VA Missouri and Illinois Healthcare (multiple facilities)')
        expect(care_systems[9]['healthCareSystemName']).to eq('VA Northern California Healthcare (multiple facilities)')
        # rubocop:enable Layout/LineLength
      end
    end
  end
end
