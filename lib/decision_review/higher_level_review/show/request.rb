# frozen_string_literal: true

module DecisionReview
  module HigherLevelReview
    module Show
      class Request < DecisionReview::Request
        def perform_args
          [:get, "higher_level_reviews/#{data.uuid}"]
        end

        def schema_errors
          []
        end
      end
    end
  end
end
