# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe 'V1::HigherLevelReviews', type: :request do
  let(:user) { build(:user, :loa3) }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:success_log_args) do
    {
      message: 'Overall claim submission success!',
      user_uuid: user.uuid,
      action: 'Overall claim submission',
      form_id: '996',
      upstream_system: nil,
      downstream_system: 'Lighthouse',
      is_success: true,
      http: {
        status_code: 200,
        body: '[Redacted]'
      }
    }
  end
  let(:error_log_args) do
    {
      message: 'Overall claim submission failure!',
      user_uuid: user.uuid,
      action: 'Overall claim submission',
      form_id: '996',
      upstream_system: nil,
      downstream_system: 'Lighthouse',
      is_success: false,
      http: {
        status_code: 422,
        body: anything
      }
    }
  end

  let(:extra_error_log_message) do
    'BackendServiceException: {:source=>"Common::Client::Errors::ClientError raised in DecisionReviewV1::Service", ' \
      ':code=>"DR_422"}'
  end

  before { sign_in_as(user) }

  describe '#create' do
    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?', 'V1::HigherLevelReviewsController#create exception % (HLR_V1)'
    end

    subject do
      post '/v1/higher_level_reviews',
           params: VetsJsonSchema::EXAMPLES.fetch('HLR-CREATE-REQUEST-BODY_V1').to_json,
           headers:
    end

    it 'creates an HLR' do
      VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-200_V1') do
        # Create an InProgressForm
        in_progress_form = create(:in_progress_form, user_uuid: user.uuid, form_id: '20-0996')
        expect(in_progress_form).not_to be_nil

        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(success_log_args)
        allow(StatsD).to receive(:increment)
        expect(StatsD).to receive(:increment).with('decision_review.form_996.overall_claim_submission.success')

        subject
        expect(response).to be_successful
        appeal_uuid = JSON.parse(response.body)['data']['id']
        expect(AppealSubmission.where(submitted_appeal_uuid: appeal_uuid).first).to be_truthy
        # InProgressForm should be destroyed after successful submission
        in_progress_form = InProgressForm.find_by(user_uuid: user.uuid, form_id: '20-0996')
        expect(in_progress_form).to be_nil
        # SavedClaim should be created with request data
        saved_claim = SavedClaim::HigherLevelReview.find_by(guid: appeal_uuid)
        expect(saved_claim.form).to eq(VetsJsonSchema::EXAMPLES.fetch('HLR-CREATE-REQUEST-BODY_V1').to_json)
      end
    end

    it 'adds to the PersonalInformationLog when an exception is thrown' do
      VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-422_V1') do
        expect(personal_information_logs.count).to be 0

        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with(error_log_args)
        expect(Rails.logger).to receive(:error).with(
          message: "Exception occurred while submitting Higher Level Review: #{extra_error_log_message}",
          backtrace: anything
        )
        expect(Rails.logger).to receive(:error).with(extra_error_log_message, anything)
        allow(StatsD).to receive(:increment)
        expect(StatsD).to receive(:increment).with('decision_review.form_996.overall_claim_submission.failure')

        subject
        expect(personal_information_logs.count).to be 1
        pil = personal_information_logs.first
        %w[
          first_name last_name birls_id icn edipi mhv_correlation_id
          participant_id vet360_id ssn assurance_level birth_date
        ].each { |key| expect(pil.data['user'][key]).to be_truthy }
        %w[message backtrace key response_values original_status original_body]
          .each { |key| expect(pil.data['error'][key]).to be_truthy }
        expect(pil.data['additional_data']['request']['body']).not_to be_empty
      end
    end
  end
end
