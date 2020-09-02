# frozen_string_literal: true

require_relative '../../response.rb'

module DecisionReview
  module HigherLevelReview
    module GetContestableIssues
      class Response < DecisionReview::Response
        SCHEMA_REGEX = /HLR-GET-CONTESTABLE-ISSUES-RESPONSE-(\d+)/
      end
    end
  end
end
