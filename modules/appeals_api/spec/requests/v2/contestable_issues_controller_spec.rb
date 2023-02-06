# frozen_string_literal: true

require 'rails_helper'
require_relative AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_contestable_issues.rb')

describe AppealsApi::V2::DecisionReviews::ContestableIssuesController, type: :request do
  include_examples 'contestable issues index requests',
                   decision_review_type: 'higher_level_reviews',
                   benefit_type: 'compensation',
                   version: 'v2'

  describe 'using versioned namespace route with oauth' do
    include_examples 'contestable issues index requests',
                     decision_review_type: 'higher_level_reviews',
                     benefit_type: 'compensation',
                     use_versioned_namespace_route: true,
                     version: 'v2'

    it_behaves_like(
      'an endpoint with OpenID auth',
      AppealsApi::ContestableIssues::V0::ContestableIssuesController::OAUTH_SCOPES[:GET]
    ) do
      let(:path) do
        '/services/appeals/contestable_issues/v0/contestable_issues/higher_level_reviews?benefit_type=compensation'
      end
      let(:headers) { { 'X-VA-SSN': '872958715', 'X-VA-Receipt-Date': '2019-12-01' } }

      def make_request(auth_header)
        VCR.use_cassette('caseflow/higher_level_reviews/contestable_issues') do
          get(path, headers: headers.merge(auth_header))
        end
      end
    end
  end

  it 'errors are in  JsonAPI ErrorObject format' do
    opts = { decision_review_type: 'higher_level_review', benefit_type: 'compensation', version: 'v2' }
    get_issues ssn: 'abcdefghi', options: opts
    error = JSON.parse(response.body)['errors'][0]
    expect(error['detail']).to eq "'abcdefghi' did not match the defined pattern"
    expect(error['code']).to eq '143'
    expect(error['source']['pointer']).to eq '/X-VA-SSN'
    expect(error['meta']['regex']).to be_present
  end
end
