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
          all_triage_teams = client.get_all_triage_teams('1234')
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
          client.get_all_triage_teams('1234')
          expect(AllTriageTeams.get_cached('1234-all-triage-teams')).to be_nil
        end
      end
    end

    it 'caches triage_team_id and station_number via TriageTeamCache' do
      VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients' do
        VCR.use_cassette('sm_client/get_unique_care_systems') do
          client.get_all_triage_teams('1234')

          cached_data = TriageTeamCache.get_cached('1234-all-triage-teams-station-numbers')
          expect(cached_data).not_to be_nil
          expect(cached_data).to be_an(Array)
          expect(cached_data.first).to respond_to(:triage_team_id)
          expect(cached_data.first).to respond_to(:station_number)
        end
      end
    end

    it 'caches only minimal triage team data with correct attributes' do
      VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients' do
        VCR.use_cassette('sm_client/get_unique_care_systems') do
          collection = client.get_all_triage_teams('user-uuid-123')

          cached_data = TriageTeamCache.get_cached('user-uuid-123-all-triage-teams-station-numbers')
          expect(cached_data.length).to eq(collection.data.length)

          # Verify cached data matches the original collection's triage_team_id and station_number
          collection.data.each_with_index do |team, index|
            expect(cached_data[index].triage_team_id).to eq(team.triage_team_id)
            expect(cached_data[index].station_number).to eq(team.station_number)
          end
        end
      end
    end

    describe '#get_triage_teams_station_numbers' do
      it 'returns cached triage team station numbers when cache exists' do
        # Pre-populate the cache
        cache_key = "#{client.session.user_uuid}-all-triage-teams-station-numbers"
        cached_data = [
          { triage_team_id: 123, station_number: '456' },
          { triage_team_id: 789, station_number: '012' }
        ]
        TriageTeamCache.set_cached(cache_key, cached_data)

        result = client.get_triage_teams_station_numbers

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first.triage_team_id).to eq(123)
        expect(result.first.station_number).to eq('456')
        expect(result.last.triage_team_id).to eq(789)
        expect(result.last.station_number).to eq('012')
      end

      it 'fetches and caches data when cache is empty' do
        VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients' do
          VCR.use_cassette('sm_client/get_unique_care_systems') do
            result = client.get_triage_teams_station_numbers

            expect(result).to be_an(Array)
            expect(result).not_to be_empty
            expect(result.first).to respond_to(:triage_team_id)
            expect(result.first).to respond_to(:station_number)
          end
        end
      end

      it 'returns empty array when API returns no data' do
        VCR.use_cassette 'sm_client/triage_teams/gets_empty_all_triage_team_recipients' do
          VCR.use_cassette('sm_client/get_unique_care_systems') do
            result = client.get_triage_teams_station_numbers

            # When cache is empty and API returns empty, result is an empty array
            expect(result).to be_an(Array)
            expect(result).to be_empty
          end
        end
      end
    end

    describe 'OH migration status check' do
      let(:oh_service) { instance_double(MHV::OhFacilitiesHelper::Service) }

      before do
        allow(MHV::OhFacilitiesHelper::Service).to receive(:new).and_return(oh_service)
      end

      it 'sets blocked_status and migrating_to_oh to true when station is in p3 phase' do
        allow(oh_service).to receive(:get_phases_for_station_numbers).and_return({ '979' => 'p3' })

        VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients' do
          VCR.use_cassette('sm_client/get_unique_care_systems') do
            collection = client.get_all_triage_teams('1234')

            collection.data.each do |team|
              expect(team.blocked_status).to be true
              expect(team.migrating_to_oh).to be true
            end
          end
        end
      end

      it 'sets blocked_status and migrating_to_oh to true when station is in p4 phase' do
        allow(oh_service).to receive(:get_phases_for_station_numbers).and_return({ '979' => 'p4' })

        VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients' do
          VCR.use_cassette('sm_client/get_unique_care_systems') do
            collection = client.get_all_triage_teams('1234')

            collection.data.each do |team|
              expect(team.blocked_status).to be true
              expect(team.migrating_to_oh).to be true
            end
          end
        end
      end

      it 'sets blocked_status and migrating_to_oh to true when station is in p5 phase' do
        allow(oh_service).to receive(:get_phases_for_station_numbers).and_return({ '979' => 'p5' })

        VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients' do
          VCR.use_cassette('sm_client/get_unique_care_systems') do
            collection = client.get_all_triage_teams('1234')

            collection.data.each do |team|
              expect(team.blocked_status).to be true
              expect(team.migrating_to_oh).to be true
            end
          end
        end
      end

      it 'sets blocked_status and migrating_to_oh to true when station is in p6 phase' do
        allow(oh_service).to receive(:get_phases_for_station_numbers).and_return({ '979' => 'p6' })

        VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients' do
          VCR.use_cassette('sm_client/get_unique_care_systems') do
            collection = client.get_all_triage_teams('1234')

            collection.data.each do |team|
              expect(team.blocked_status).to be true
              expect(team.migrating_to_oh).to be true
            end
          end
        end
      end

      it 'does not modify blocked_status or migrating_to_oh when station is not in p3-p6 phase' do
        allow(oh_service).to receive(:get_phases_for_station_numbers).and_return({ '979' => 'p2' })

        VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients' do
          VCR.use_cassette('sm_client/get_unique_care_systems') do
            collection = client.get_all_triage_teams('1234')

            # The original cassette has blocked_status: false
            collection.data.each do |team|
              expect(team.blocked_status).to be false
              expect(team.migrating_to_oh).to be false
            end
          end
        end
      end

      it 'does not modify blocked_status or migrating_to_oh when phase is nil' do
        allow(oh_service).to receive(:get_phases_for_station_numbers).and_return({})

        VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients' do
          VCR.use_cassette('sm_client/get_unique_care_systems') do
            collection = client.get_all_triage_teams('1234')

            collection.data.each do |team|
              expect(team.blocked_status).to be false
              expect(team.migrating_to_oh).to be false
            end
          end
        end
      end

      it 'does not modify blocked_status or migrating_to_oh when station is in p7 phase' do
        allow(oh_service).to receive(:get_phases_for_station_numbers).and_return({ '979' => 'p7' })

        VCR.use_cassette 'sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients' do
          VCR.use_cassette('sm_client/get_unique_care_systems') do
            collection = client.get_all_triage_teams('1234')

            collection.data.each do |team|
              expect(team.blocked_status).to be false
              expect(team.migrating_to_oh).to be false
            end
          end
        end
      end
    end
  end
end
