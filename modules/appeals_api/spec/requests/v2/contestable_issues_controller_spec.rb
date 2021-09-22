# frozen_string_literal: true

require 'rails_helper'
require_relative AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_contestable_issues.rb')

describe AppealsApi::V2::DecisionReviews::ContestableIssuesController, type: :request do
  include_examples 'contestable issues index requests',
                   decision_review_type: 'higher_level_reviews',
                   benefit_type: 'compensation',
                   version: 'v2'

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
