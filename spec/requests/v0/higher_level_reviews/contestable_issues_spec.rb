# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe 'V0::HigherLevelReviews::ContestableIssues', type: :request do
  let(:user) { build(:user, :loa3) }

  before { sign_in_as(user) }

  describe '#index' do
    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?',
                                   'V0::HigherLevelReviews::ContestableIssuesController#index exception % (HLR)'
    end

    subject { get '/v0/higher_level_reviews/contestable_issues/compensation' }

    it 'fetches issues that the Veteran could contest via a higher-level review' do
      VCR.use_cassette('decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-200') do
        subject
        expect(response).to be_successful
        expect(JSON.parse(response.body)['data']).to be_an Array
      end
    end

    it 'adds to the PersonalInformationLog when an exception is thrown' do
      VCR.use_cassette('decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-404') do
        expect(personal_information_logs.count).to be 0
        subject
        expect(personal_information_logs.count).to be 1
        pil = personal_information_logs.first
        expect(pil.data['user']).to be_truthy
        expect(pil.data['error']).to be_truthy
      end
    end
  end
end
