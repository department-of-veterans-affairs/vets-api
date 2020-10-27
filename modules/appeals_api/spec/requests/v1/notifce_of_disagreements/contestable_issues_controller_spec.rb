# frozen_string_literal: true

require 'rails_helper'
require_relative AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_contestable_issues.rb')

describe AppealsApi::V1::DecisionReviews::NoticeOfDisagreements::ContestableIssuesController, type: :request do
  include_examples 'contestable issues index requests',
                   decision_review_type: 'notice_of_disagreements',
                   benefit_type: ''
end
