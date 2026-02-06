# frozen_string_literal: true

require 'mhv/oh_facilities_helper/service'

module SM
  class Client < Common::Client::Base
    ##
    # Module containing triage team-related methods for the SM Client
    #
    module TriageTeams
      ##
      # Get a collection of triage team recipients
      #
      # @return [Common::Collection[TriageTeam]]
      #
      def get_triage_teams(user_uuid, use_cache)
        cache_key = "#{user_uuid}-triage-teams"
        get_cached_or_fetch_data(use_cache, cache_key, TriageTeam) do
          json = perform(:get, 'triageteam', nil, token_headers).body
          Vets::Collection.new(json[:data], TriageTeam, metadata: json[:metadata], errors: json[:errors])
        end
      end

      ##
      # Get a collection of all triage team recipients, including blocked
      # with detailed attributes per each team
      # including a total tally of associated and locked teams
      #
      # @note Only triage_team_id and station_number are cached via TriageTeamCache model
      # @return [Common::Collection[AllTriageTeams]]
      #
      def get_all_triage_teams(user_uuid)
        path = append_requires_oh_messages_query('alltriageteams', 'requiresOHTriageGroup')
        json = perform(:get, path, nil, token_headers).body
        collection = Vets::Collection.new(json[:data], AllTriageTeams, metadata: json[:metadata],
                                                                       errors: json[:errors])

        update_teams_migration_status(collection.data)
        cache_triage_team_station_numbers(user_uuid, collection.data)

        collection
      end

      ##
      # Update preferredTeam value for a patient's list of triage teams
      #
      # @param updated_triage_teams_list [Array] an array of objects
      # with triage_team_id and preferred_team values
      # @return [Fixnum] the response status code
      #
      def update_triage_team_preferences(updated_triage_teams_list)
        custom_headers = token_headers.merge('Content-Type' => 'application/json')
        response = perform(:post, 'preferences/patientpreferredtriagegroups', updated_triage_teams_list, custom_headers)
        response&.status
      end

      ##
      # Get cached triage team station numbers, fetching from API if not cached
      #
      # @return [Array<TriageTeamCache>, nil] cached triage teams with triage_team_id and station_number
      #
      def get_triage_teams_station_numbers
        cache_key = "#{session.user_uuid}-all-triage-teams-station-numbers"
        cached = TriageTeamCache.get_cached(cache_key)
        return cached if cached.present?

        get_all_triage_teams(session.user_uuid)
        TriageTeamCache.get_cached(cache_key)
      end

      private

      # Updates blocked_status and migrating_to_oh for teams in p3-p6 migration phases
      def update_teams_migration_status(teams)
        oh_service = MHV::OhFacilitiesHelper::Service.new(current_user)
        station_numbers = teams.map(&:station_number).compact.uniq
        phases_map = oh_service.get_phases_for_station_numbers(station_numbers)

        teams.each do |team|
          phase = phases_map[team.station_number.to_s]
          if %w[p3 p4 p5 p6].include?(phase)
            team.blocked_status = true
            team.migrating_to_oh = true
          else
            team.migrating_to_oh = false
          end
        end
      end

      # Caches minimal triage team data (triage_team_id and station_number)
      def cache_triage_team_station_numbers(user_uuid, teams)
        minimal_data = teams.map do |team|
          { triage_team_id: team.triage_team_id, station_number: team.station_number }
        end
        cache_key = "#{user_uuid}-all-triage-teams-station-numbers"
        TriageTeamCache.set_cached(cache_key, minimal_data)
      end
    end
  end
end
