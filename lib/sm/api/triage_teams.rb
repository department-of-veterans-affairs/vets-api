# frozen_string_literal: true
require 'common/models/collection'

module SM
  module API
    module TriageTeams
      def get_triage_teams
        json = perform(:get, 'triageteam', nil, token_headers).body
        Common::Collection.new(TriageTeam, json)
      end
    end
  end
end
