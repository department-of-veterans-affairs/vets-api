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
    let(:decision_review_type) { 'notice_of_disagreements' }
    let(:base_path) { '/services/appeals/v2/decision_reviews/contestable_issues' }
    let(:path) { "#{base_path}/#{decision_review_type}" }
    let(:receipt_date) { '2019-02-20' }
    let(:headers) do
      {
        'X-VA-SSN': '123456789',
        'X-VA-Receipt-Date': receipt_date
      }
    end

    context 'with valid inputs' do
      it 'returns a 200 response' do
        VCR.use_cassette("caseflow/#{decision_review_type}/contestable_issues") do
          get(path, headers:)
        end

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when receipt date is too early' do
      let(:receipt_date) { '2019-02-19' }

      it 'returns a 422 error with details' do
        VCR.use_cassette("caseflow/#{decision_review_type}/contestable_issues") do
          get(path, headers:)
        end

        expect(response).to have_http_status(:unprocessable_entity)
        error = JSON.parse(response.body)['errors'][0]
        expect(error['title']).to eql('Validation error')
        expect(error['detail']).to eql('Receipt date cannot be before 2019-02-20')
        expect(error['source']['header']).to eql('X-VA-Receipt-Date')
        expect(error['status']).to eql('422')
      end
    end

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
