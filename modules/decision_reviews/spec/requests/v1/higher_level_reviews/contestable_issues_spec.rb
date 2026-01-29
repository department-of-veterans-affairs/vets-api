# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/vcr_helper'
require 'decision_reviews/v1/appealable_issues/service'
require 'decision_reviews/v1/appealable_issues/configuration'

RSpec.describe 'DecisionReviews::V1::HigherLevelReviews::ContestableIssues', type: :request do
  # ICN must match the ICN in VCR cassette URLs since it's part of the query parameters
  let(:user) { build(:user, :loa3, icn: '1012832025V743496') }
  let(:success_log_args) do
    {
      message: 'Get contestable issues success!',
      user_uuid: user.uuid,
      action: 'Get contestable issues',
      form_id: '996',
      upstream_system: 'Lighthouse',
      downstream_system: nil,
      is_success: true,
      http: {
        status_code: 200,
        body: '[Redacted]'
      }
    }
  end
  let(:error_log_args) do
    {
      message: 'Get contestable issues failure!',
      user_uuid: user.uuid,
      action: 'Get contestable issues',
      form_id: '996',
      upstream_system: 'Lighthouse',
      downstream_system: nil,
      is_success: false,
      http: {
        status_code: 404,
        body: anything
      }
    }
  end
  let(:appealable_issues_service_success_log_args) do
    {
      message: 'Get contestable issues success!',
      user_uuid: user.uuid,
      action: 'Get contestable issues',
      form_id: '996',
      upstream_system: 'Lighthouse (New Appealable Issues API)',
      downstream_system: nil,
      is_success: true,
      http: {
        status_code: 200,
        body: '[Redacted]'
      }
    }
  end

  before { sign_in_as(user) }

  describe '#index' do
    subject { get '/decision_reviews/v1/higher_level_reviews/contestable_issues/compensation' }

    around do |example|
      Timecop.freeze(Time.zone.parse('2026-01-23')) do
        example.run
      end
    end

    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?',
                                   'DecisionReviews::V1::HigherLevelReviews::ContestableIssuesController#index exception % (HLR_V1)' # rubocop:disable Layout/LineLength
    end

    context 'with feature flag disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:decision_review_use_new_appealable_issues_service).and_return(false)
      end

      it 'fetches issues that the Veteran could contest via a higher-level review' do
        VCR.use_cassette('decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1') do
          VCR.use_cassette('decision_review/HLR-GET-LEGACY_APPEALS-RESPONSE-200_V1') do
            allow(Rails.logger).to receive(:info)
            expect(Rails.logger).to receive(:info).with(success_log_args)
            subject
            expect(response).to be_successful
            expect(JSON.parse(response.body)['data']).to be_an Array
            expect(JSON.parse(response.body)['data'].length).to be 4
          end
        end
      end

      it 'fetches issues that the Veteran could contest via a higher-level review, but empty Legacy Appeals' do
        VCR.use_cassette('decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1') do
          VCR.use_cassette('decision_review/HLR-GET-LEGACY_APPEALS-RESPONSE-200-EMPTY_V1') do
            subject
            expect(response).to be_successful
            expect(JSON.parse(response.body)['data']).to be_an Array
            expect(JSON.parse(response.body)['data'].length).to be 4
          end
        end
      end

      it 'adds to the PersonalInformationLog when an exception is thrown' do
        VCR.use_cassette('decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-404_V1') do
          expect(personal_information_logs.count).to be 0
          allow(Rails.logger).to receive(:error)
          expect(Rails.logger).to receive(:error).with(error_log_args)
          subject
          expect(personal_information_logs.count).to be 1
          pil = personal_information_logs.first
          expect(pil.data['user']).to be_truthy
          expect(pil.data['error']).to be_truthy
        end
      end
    end

    context 'with feature flag enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:decision_review_use_new_appealable_issues_service).and_return(true)
        # Stub access_token directly to avoid OAuth setup
        allow_any_instance_of(DecisionReviews::V1::AppealableIssues::Configuration)
          .to receive(:access_token).and_return('fake-token-12345')
      end

      it 'uses appealable issues service and returns issues successfully' do
        VCR.use_cassette('decision_review/appealable_issues/HLR-GET-APPEALABLE-ISSUES-RESPONSE-200') do
          VCR.use_cassette('decision_review/HLR-GET-LEGACY_APPEALS-RESPONSE-200_V1') do
            allow(Rails.logger).to receive(:info)
            expect(Rails.logger).to receive(:info).with(appealable_issues_service_success_log_args)
            subject
            expect(response).to be_successful
            expect(JSON.parse(response.body)['data']).to be_an Array
            expect(JSON.parse(response.body)['data'].length).to be 4
          end
        end
      end

      it 'fetches issues that the Veteran could contest via a higher-level review, but empty Legacy Appeals' do
        VCR.use_cassette('decision_review/appealable_issues/HLR-GET-APPEALABLE-ISSUES-RESPONSE-200') do
          VCR.use_cassette('decision_review/HLR-GET-LEGACY_APPEALS-RESPONSE-200-EMPTY_V1') do
            subject
            expect(response).to be_successful
            expect(JSON.parse(response.body)['data']).to be_an Array
            expect(JSON.parse(response.body)['data'].length).to be 4
          end
        end
      end

      it 'logs errors to PersonalInformationLog when an exception is thrown' do
        VCR.use_cassette('decision_review/appealable_issues/HLR-GET-APPEALABLE-ISSUES-RESPONSE-404') do
          # Override ICN to simulate veteran not found scenario
          allow_any_instance_of(User).to receive(:icn).and_return('0000000000V000000')
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
end
