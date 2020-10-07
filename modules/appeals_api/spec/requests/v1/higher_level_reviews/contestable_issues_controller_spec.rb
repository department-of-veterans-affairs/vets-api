# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/shared_examples_contestable_issues'

describe AppealsApi::V1::DecisionReviews::HigherLevelReviews::ContestableIssuesController, type: :request do
  include_examples 'contestable issues index requests', appeal_type: 'higher_level_reviews'
end
