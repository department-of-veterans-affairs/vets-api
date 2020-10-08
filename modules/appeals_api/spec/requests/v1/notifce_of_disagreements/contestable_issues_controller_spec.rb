# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/shared_examples_contestable_issues'

describe AppealsApi::V1::DecisionReviews::NoticeOfDisagreements::ContestableIssuesController, type: :request do
  include_examples 'contestable issues index requests',
                   appeal_type: 'notice_of_disagreements',
                   benefit_type: ''
end
