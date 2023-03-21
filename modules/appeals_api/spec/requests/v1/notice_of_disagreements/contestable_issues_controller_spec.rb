# frozen_string_literal: true

require 'rails_helper'
require_relative AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_contestable_issues.rb')

describe AppealsApi::V1::DecisionReviews::NoticeOfDisagreements::ContestableIssuesController, type: :request do
  include_examples 'Contestable Issues API v0 and Decision Reviews v1 & v2 shared request examples',
                   base_path: '/services/appeals/v1/decision_reviews/notice_of_disagreements/contestable_issues'
end
