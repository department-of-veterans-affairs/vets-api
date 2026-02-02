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
  end
end
