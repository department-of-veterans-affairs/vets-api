# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/vcr_helper'

RSpec.describe 'DecisionReviews::V2::HigherLevelReviews', type: :request do
  let(:user) { build(:user, :with_terms_of_use_agreement, :loa3) }
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
      },
      version: 'V2'
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
        body: response_error_body
      },
      version: 'V2'
    }
  end

  let(:response_error_body) do
    {
      'errors' => [{ 'title' => 'Missing required fields',
                     'detail' => 'One or more expected fields were not found',
                     'code' => '145',
                     'source' => { 'pointer' => '/' },
                     'status' => '422',
                     'meta' => { 'missing_fields' => %w[data included] } }]
    }
  end

  let(:extra_error_log_message) do
    'BackendServiceException: {:source=>"Common::Client::Errors::ClientError raised in DecisionReviews::V1::Service", :code=>"DR_422"}' # rubocop:disable Layout/LineLength
  end

  before { sign_in_as(user) }

  describe '#create' do
    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?',
                                   'DecisionReviews::V2::HigherLevelReviewsController#create exception % (HLR_V2)'
    end

    subject do
      post '/decision_reviews/v2/higher_level_reviews',
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

    context 'when an error occurs with the api call' do
      before do
        allow(Flipper).to receive(:enabled?).with(:decision_review_service_common_exceptions_enabled).and_return(false)
      end

      it 'adds to the PersonalInformationLog' do
        VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-422_V1') do
          expect(personal_information_logs.count).to be 0

          allow(Rails.logger).to receive(:error)
          expect(Rails.logger).to receive(:error).with(error_log_args)
          expect(Rails.logger).to receive(:error).with(
            message: "Exception occurred while submitting Higher Level Review: #{extra_error_log_message}",
            backtrace: anything
          )
          expect(Rails.logger).to receive(:error) do |message|
            expect(message).to include(extra_error_log_message)
          end
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

    context 'when an error occurs in the transaction' do
      shared_examples 'rolledback transaction' do |model|
        before do
          allow_any_instance_of(model).to receive(:save!).and_raise(ActiveModel::Error) # stub a model error
        end

        it 'rollsback transaction' do
          VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-200_V1') do
            expect(subject).to eq 500

            # check that transaction rolled back / records were not persisted
            expect(AppealSubmission.count).to eq 0
            expect(SavedClaim.count).to eq 0
          end
        end
      end

      context 'for AppealSubmission' do
        it_behaves_like 'rolledback transaction', AppealSubmission
      end

      context 'for SavedClaim' do
        it_behaves_like 'rolledback transaction', SavedClaim
      end
    end
  end
end
