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

        # Check each team for OH migration status and update blocked_status if in p3-p6
        oh_service = MHV::OhFacilitiesHelper::Service.new(current_user)
        collection.data.each do |team|
          phase = oh_service.get_phase_for_station_number(team.station_number)
          if %w[p3 p4 p5 p6].include?(phase)
            team.blocked_status = true
            team.migrating_to_oh = true
          end
        end

        # Cache only triage_team_id and station_number via TriageTeamCache model
        minimal_data = collection.data.map do |team|
          { triage_team_id: team.triage_team_id, station_number: team.station_number }
        end
        cache_key = "#{user_uuid}-all-triage-teams-station-numbers"
        TriageTeamCache.set_cached(cache_key, minimal_data)

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
        get_cached_or_fetch_data(true, cache_key, TriageTeamCache) do
          get_all_triage_teams(session.user_uuid)
        end
        TriageTeamCache.get_cached(cache_key)
      end
    end
  end
end
