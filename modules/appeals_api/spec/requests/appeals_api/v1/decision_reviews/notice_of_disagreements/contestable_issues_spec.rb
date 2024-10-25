# frozen_string_literal: true

require 'rails_helper'
require_relative AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_contestable_issues.rb')

Rspec.describe AppealsApi::V1::DecisionReviews::NoticeOfDisagreements::ContestableIssuesController, type: :request do
  include_examples 'Appealable Issues API v0 and Decision Reviews v1 & v2 shared request examples',
                   base_path: '/services/appeals/v1/decision_reviews/notice_of_disagreements/contestable_issues'

  describe '#index' do
    let(:decision_review_type) { 'notice_of_disagreements' }
    let(:path) { "/services/appeals/v1/decision_reviews/#{decision_review_type}/contestable_issues" }

    it_behaves_like 'an endpoint requiring gateway origin headers',
                    headers: {
                      'X-VA-SSN': '123456789',
                      'X-VA-Receipt-Date': '2019-12-01'
                    } do
      def make_request(headers)
        VCR.use_cassette("caseflow/#{decision_review_type}/contestable_issues") do
          get(path, headers:)
        end
      end
    end
  end
end
