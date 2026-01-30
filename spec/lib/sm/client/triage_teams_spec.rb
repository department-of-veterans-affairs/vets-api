# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe 'sm client' do
  describe 'triage_teams' do
    subject(:client) { @client }

    before do
      VCR.use_cassette 'sm_client/session' do
        @client ||= begin
          client = SM::Client.new(session: { user_id: '10616687' })
          client.authenticate
          client
        end
      end
    end

    it 'gets a collection of triage team recipients', :vcr do
      folders = client.get_triage_teams('1234', false)
      expect(folders).to be_a(Vets::Collection)
      expect(folders.type).to eq(TriageTeam)
    end

    it 'populates health care system names' do
      VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients' do
        VCR.use_cassette('sm_client/get_unique_care_systems') do
          all_triage_teams = client.get_all_triage_teams('1234', false)
          all_triage_teams.records.each { |record| expect(record.health_care_system_name).not_to be_nil }
        end
      end
    end

    it 'does not cache triage teams' do
      VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_triage_team_recipients' do
        client.get_triage_teams('1234', false)
        expect(TriageTeam.get_cached('1234-triage-teams')).to be_nil
      end
    end

    it 'does not cache all triage teams' do
      VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients' do
        VCR.use_cassette('sm_client/get_unique_care_systems') do
          client.get_all_triage_teams('1234', false)
          expect(AllTriageTeams.get_cached('1234-all-triage-teams')).to be_nil
        end
      end
    end

    describe '#find_recipient_facility_ids' do
      it 'returns the station number for a matching recipient' do
        VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients' do
          # The cassette contains a triage team with ID 4399547 and station_number '979'
          result = client.find_recipient_facility_ids('1234', 4_399_547, use_cache: false)
          expect(result).to eq(['979'])
        end
      end

      it 'returns nil when recipient_id is blank' do
        result = client.find_recipient_facility_ids('1234', nil, use_cache: false)
        expect(result).to be_nil
      end

      it 'returns nil when recipient_id is not found' do
        VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients' do
          result = client.find_recipient_facility_ids('1234', 999_999, use_cache: false)
          expect(result).to be_nil
        end
      end

      it 'raises error when get_all_triage_teams fails' do
        error_client = SM::Client.new(session: { user_id: '10616687' })
        allow(error_client).to receive(:get_all_triage_teams).and_raise(StandardError.new('API error'))
        expect { error_client.find_recipient_facility_ids('1234', 4_399_547, use_cache: false) }
          .to raise_error(StandardError, 'API error')
      end
    end
  end
end
