# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/vcr_helper'

RSpec.describe 'DecisionReviews::V1::NoticeOfDisagreements', type: :request do
  let(:user) do
    build(:user,
          :loa3,
          :with_terms_of_use_agreement,
          mhv_correlation_id: 'some-mhv_correlation_id',
          birls_id: 'some-birls_id',
          participant_id: 'some-participant_id',
          vet360_id: 'some-vet360_id')
  end
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }

  let(:error_log_args) do
    {
      message: 'Overall claim submission failure!',
      user_uuid: user.uuid,
      action: 'Overall claim submission',
      form_id: '10182',
      upstream_system: nil,
      downstream_system: 'Lighthouse',
      is_success: false,
      http: {
        status_code: 422,
        body: response_error_body
      }
    }
  end

  let(:response_error_body) do
    {
      'errors' => [{ 'title' => 'Missing required fields',
                     'detail' => 'One or more expected fields were not found',
                     'code' => '145',
                     'source' => { 'pointer' => '/data/attributes' },
                     'status' => '422',
                     'meta' => { 'missing_fields' => ['boardReviewOption'] } }]
    }
  end

  before { sign_in_as(user) }

  describe '#create' do
    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?',
                                   'DecisionReviews::V1::NoticeOfDisagreementsController#create exception % (NOD_V1)'
    end

    subject do
      post '/decision_reviews/v1/notice_of_disagreements',
           params: test_request_body.to_json,
           headers:
    end

    let(:extra_error_log_message) do
      'BackendServiceException: {:source=>"Common::Client::Errors::ClientError raised in DecisionReviews::V1::Service", :code=>"DR_422"}' # rubocop:disable Layout/LineLength
    end

    let(:test_request_body) do
      JSON.parse Rails.root.join('spec', 'fixtures', 'notice_of_disagreements',
                                 'valid_NOD_create_request.json').read
    end

    context 'when valid data is submitted' do
      it 'creates an NOD and logs to StatsD and logger' do
        VCR.use_cassette('decision_review/NOD-CREATE-RESPONSE-200_V1') do
          allow(Rails.logger).to receive(:info)
          expect(Rails.logger).to receive(:info).with({
                                                        message: 'Overall claim submission success!',
                                                        user_uuid: user.uuid,
                                                        action: 'Overall claim submission',
                                                        form_id: '10182',
                                                        upstream_system: nil,
                                                        downstream_system: 'Lighthouse',
                                                        is_success: true,
                                                        http: {
                                                          status_code: 200,
                                                          body: '[Redacted]'
                                                        }
                                                      })

          allow(StatsD).to receive(:increment)
          expect(StatsD).to receive(:increment).with('decision_review.form_10182.overall_claim_submission.success')
          previous_appeal_submission_ids = AppealSubmission.all.pluck :submitted_appeal_uuid
          # Create an InProgressForm
          in_progress_form = create(:in_progress_form, user_uuid: user.uuid, form_id: '10182')
          expect(in_progress_form).not_to be_nil
          subject
          expect(response).to be_successful
          parsed_response = JSON.parse(response.body)
          id = parsed_response['data']['id']
          expect(previous_appeal_submission_ids).not_to include id
          appeal_submission = AppealSubmission.find_by(submitted_appeal_uuid: id)
          expect(appeal_submission.type_of_appeal).to eq('NOD')
          # AppealSubmissionUpload should be created for each form attachment
          appeal_submission_uploads = AppealSubmissionUpload.where(appeal_submission:)
          expect(appeal_submission_uploads.count).to eq 1
          # Evidence upload job is enqueued with non-engine job
          expect(DecisionReviews::SubmitUpload).to have_enqueued_sidekiq_job(appeal_submission_uploads.first.id)
          # InProgressForm should be destroyed after successful submission
          in_progress_form = InProgressForm.find_by(user_uuid: user.uuid, form_id: '10182')
          expect(in_progress_form).to be_nil
          # SavedClaim should be created with request data
          saved_claim = SavedClaim::NoticeOfDisagreement.find_by(guid: id)
          expect(JSON.parse(saved_claim.form)).to eq(test_request_body)
        end
      end
    end

    it 'adds to the PersonalInformationLog when an exception is thrown and logs to StatsD and logger' do
      expect(Flipper).to receive(:enabled?).with(:decision_review_service_common_exceptions_enabled).and_return(false)

      VCR.use_cassette('decision_review/NOD-CREATE-RESPONSE-422_V1') do
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with(error_log_args)
        expect(Rails.logger).to receive(:error).with(
          message: "Exception occurred while submitting Notice Of Disagreement: #{extra_error_log_message}",
          backtrace: anything
        )
        expect(Rails.logger).to receive(:error) do |message|
          expect(message).to include(extra_error_log_message)
        end
        allow(StatsD).to receive(:increment)
        expect(StatsD).to receive(:increment).with('decision_review.form_10182.overall_claim_submission.failure')
        expect(personal_information_logs.count).to be 0
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

        # check that transaction rolled back / records were not persisted / evidence upload job was not queued up
        expect(AppealSubmission.count).to eq 0
        expect(AppealSubmissionUpload.count).to eq 0

        expect(SavedClaim.count).to eq 0
      end
    end

    context 'when an error occurs in wrapped code' do
      shared_examples 'rolledback transaction' do |model|
        before do
          allow_any_instance_of(model).to receive(:save!).and_raise(ActiveModel::Error) # stub a model error
        end

        it 'rollsback transaction' do
          VCR.use_cassette('decision_review/NOD-CREATE-RESPONSE-200_V1') do
            expect(subject).to eq 500
            # check that transaction rolled back / records were not persisted / evidence upload job was not queued up
            expect(AppealSubmission.count).to eq 0
            expect(AppealSubmissionUpload.count).to eq 0
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
