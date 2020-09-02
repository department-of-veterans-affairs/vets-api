# frozen_string_literal: true

require_relative '../../response.rb'

module DecisionReview
  module HigherLevelReview
    module Create
      class Response < DecisionReview::Response
        SCHEMA_REGEX = /HLR-CREATE-RESPONSE-(\d+)/
      end
    end
  end
end
