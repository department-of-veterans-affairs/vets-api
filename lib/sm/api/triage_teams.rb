# frozen_string_literal: true
require 'common/models/collection'

module SM
  module API
    ###################################################################################################################
    ## TriageTeams
    ## This module defines the secure messaging triage team actions.
    ###################################################################################################################
    module TriageTeams
      #################################################################################################################
      ## get_triage_teams
      ## Retrieves a list of triage team members that can be messaged. The set may be optionally paginated by
      ## specifying a page and a page_size (> 0).
      #################################################################################################################
      def get_triage_teams(page = 1, page_size = -1)
        json = perform(:get, 'triageteam', nil, token_headers)
        collection = Common::Collection.new(TriageTeam, json)
        page_size.positive? ? collection.paginate(page: page, per_page: page_size) : collection
      end
    end
  end
end
