# frozen_string_literal: true

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
      # @return [Common::Collection[AllTriageTeams]]
      #
      def get_all_triage_teams(user_uuid, use_cache)
        cache_key = "#{user_uuid}-all-triage-teams"
        get_cached_or_fetch_data(use_cache, cache_key, AllTriageTeams) do
          path = append_requires_oh_messages_query('alltriageteams', 'requiresOHTriageGroup')
          json = perform(:get, path, nil, token_headers).body
          Vets::Collection.new(json[:data], AllTriageTeams, metadata: json[:metadata], errors: json[:errors])
        end
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
      # Find the station number (facility ID) for a recipient triage team
      # Uses cached triage teams data to avoid additional API calls
      #
      # @param user_uuid [String] the user's UUID for cache key
      # @param recipient_id [Integer] the triage team ID of the recipient
      # @param use_cache [Boolean] whether to use cached triage teams data
      # @return [Array<String>, nil] array with the station number if found, nil otherwise
      #
      def find_recipient_facility_ids(user_uuid, recipient_id, use_cache: true)
        return nil if recipient_id.blank?

        triage_teams = get_all_triage_teams(user_uuid, use_cache)
        recipient_team = triage_teams.data.find { |team| team.triage_team_id == recipient_id }
        return nil if recipient_team.blank? || recipient_team.station_number.blank?

        [recipient_team.station_number]
      rescue => e
        Rails.logger.warn("Failed to look up recipient facility for messaging UUM: #{e.message}")
        nil
      end
    end
  end
end
