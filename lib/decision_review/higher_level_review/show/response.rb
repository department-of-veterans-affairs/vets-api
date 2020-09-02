# frozen_string_literal: true

require_relative '../../response.rb'

module DecisionReview
  module HigherLevelReview
    module Show
      class Response < DecisionReview::Response
        SCHEMA_REGEX = /HLR-SHOW-RESPONSE-(\d+)/
      end
    end
  end
end
