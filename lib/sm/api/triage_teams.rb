# frozen_string_literal: true
require 'common/models/collection'

module SM
  module API
    module TriageTeams
      # get_triage_teams: Retrieves a list of triage team members that can be messaged.
      def get_triage_teams
        json = perform(:get, 'triageteam', nil, token_headers).body
        Common::Collection.new(TriageTeam, json)
      end
    end
  end
end
