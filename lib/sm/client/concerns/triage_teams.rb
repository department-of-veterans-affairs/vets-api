# frozen_string_literal: true

#
# Triage teams related operations extracted from SM::Client to keep the main client
# class concise. Provides retrieval, cache-aware variants, preference updates, and
# helpers to derive unique care system metadata.
#
module SM
  class Client
    module TriageTeams
      ##
      # Fetch a collection of triage team recipients.
      # Optionally serves from a short‑lived cache keyed per user.
      #
      # @param user_uuid [String]
      # @param use_cache [Boolean] when true, attempt to read/write cached triage teams
      # @return [Vets::Collection<TriageTeam>]
      def get_triage_teams(user_uuid, use_cache)
        cache_key = "#{user_uuid}-triage-teams"
        get_cached_or_fetch_data(use_cache, cache_key, TriageTeam) do
          json = perform(:get, 'triageteam', nil, token_headers).body
          data = Vets::Collection.new(json[:data], TriageTeam,
                                      metadata: json[:metadata], errors: json[:errors])
          TriageTeam.set_cached(cache_key, data.records) unless Flipper.enabled?(:mhv_secure_messaging_no_cache)
          data
        end
      end

      ##
      # Fetch an expanded collection of all triage teams (including blocked) with
      # detailed attributes and associated / locked team counts.
      #
      # @param user_uuid [String]
      # @param use_cache [Boolean]
      # @return [Vets::Collection<AllTriageTeams>]
      def get_all_triage_teams(user_uuid, use_cache)
        cache_key = "#{user_uuid}-all-triage-teams"
        get_cached_or_fetch_data(use_cache, cache_key, AllTriageTeams) do
          path = append_requires_oh_messages_query('alltriageteams', 'requiresOHTriageGroup')
          json = perform(:get, path, nil, token_headers).body
          data = Vets::Collection.new(json[:data], AllTriageTeams,
                                      metadata: json[:metadata], errors: json[:errors])
          AllTriageTeams.set_cached(cache_key, data.records) unless Flipper.enabled?(:mhv_secure_messaging_no_cache)
          data
        end
      end

      ##
      # Update the preferred triage team selection for the patient.
      #
      # @param updated_triage_teams_list [Array<Hash>] array of objects containing:
      #   - triage_team_id
      #   - preferred_team (Boolean)
      # @return [Integer, nil] HTTP status code
      def update_triage_team_preferences(updated_triage_teams_list)
        headers = token_headers.merge('Content-Type' => 'application/json')
        perform(:post,
                'preferences/patientpreferredtriagegroups',
                updated_triage_teams_list,
                headers)&.status
      end

      ##
      # Produce a simplified list of unique care system identifiers and names
      # derived from a collection of recipients.
      #
      # @param all_recipients [Enumerable<#station_number>]
      # @return [Array<Hash{station_number:String, health_care_system_name:String}>]
      def get_unique_care_systems(all_recipients)
        unique_ids = all_recipients.uniq(&:station_number).map(&:station_number)
        unique_names = Mobile::FacilitiesHelper.get_facility_names(unique_ids)
        unique_ids.zip(unique_names).map do |station, name|
          {
            station_number: station,
            health_care_system_name: name || station
          }
        end
      end
    end
  end
end
