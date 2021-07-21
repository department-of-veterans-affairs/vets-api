# frozen_string_literal: true

require 'rails_helper'
require_relative AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_contestable_issues.rb')

describe AppealsApi::V2::DecisionReviews::ContestableIssuesController, type: :request do
  include_examples 'contestable issues index requests',
                   decision_review_type: 'higher_level_reviews',
                   benefit_type: 'compensation',
                   version: 'v2'
end
