# frozen_string_literal: true

require 'rails_helper'
require_relative AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_contestable_issues.rb')

Rspec.describe AppealsApi::V2::DecisionReviews::ContestableIssuesController, type: :request do
  include_examples 'Appealable Issues API v0 and Decision Reviews v1 & v2 shared request examples',
                   base_path: '/services/appeals/v2/decision_reviews/contestable_issues'

  context 'with errors' do
    let(:body) { JSON.parse(response.body) }
    let(:headers) { { 'X-VA-SSN': 'abcdefghi', 'X-VA-Receipt-Date': '2019-12-01' } }
    let(:path) do
      '/services/appeals/v2/decision_reviews/contestable_issues/higher_level_reviews?benefit_type=compensation'
    end

    before { get(path, headers:) }

    it 'presents errors in JsonAPI ErrorObject format' do
      error = body['errors'].first
      expect(error['detail']).to eq "'abcdefghi' did not match the defined pattern"
      expect(error['code']).to eq '143'
      expect(error['source']['pointer']).to eq '/X-VA-SSN'
      expect(error['meta']['regex']).to be_present
    end
  end

  describe '#index' do
    let(:decision_review_type) { 'higher_level_reviews' }
    let(:base_path) { '/services/appeals/v2/decision_reviews/contestable_issues' }
    let(:path) { "#{base_path}/#{decision_review_type}?benefit_type=compensation" }

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
