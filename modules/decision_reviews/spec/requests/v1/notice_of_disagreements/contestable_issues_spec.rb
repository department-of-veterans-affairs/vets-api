# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/vcr_helper'

RSpec.describe 'DecisionReviews::V1::NoticeOfDisagreements::ContestableIssues', type: :request do
  let(:user) { build(:user, :loa3) }

  before { sign_in_as(user) }

  describe '#index' do
    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?',
                                   'DecisionReviews::V1::NoticeOfDisagreements::ContestableIssuesController#index exception % (NOD_V1)' # rubocop:disable Layout/LineLength
    end

    subject { get '/decision_reviews/v1/notice_of_disagreements/contestable_issues' }

    it 'fetches issues that the Veteran could contest via a notice of disagreement' do
      VCR.use_cassette('decision_review/NOD-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1') do
        subject
        expect(response).to be_successful
        expect(JSON.parse(response.body)['data']).to be_an Array
      end
    end

    it 'adds to the PersonalInformationLog when an exception is thrown' do
      VCR.use_cassette('decision_review/NOD-GET-CONTESTABLE-ISSUES-RESPONSE-404_V1') do
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
