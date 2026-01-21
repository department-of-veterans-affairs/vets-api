# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/vcr_helper'

RSpec.describe 'DecisionReviews::V1::SupplementalClaims', type: :request do
  let(:user) { build(:user, :loa3, :with_terms_of_use_agreement) }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:success_log_args) do
    {
      message: 'Overall claim submission success!',
      user_uuid: user.uuid,
      action: 'Overall claim submission',
      form_id: '995',
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
      form_id: '995',
      upstream_system: nil,
      downstream_system: 'Lighthouse',
      is_success: false,
      http: {
        status_code: 422,
        body: response_error_body
      }
    }
  end
  let(:extra_error_log_message) do
    'BackendServiceException: ' \
      '{:source=>"Common::Client::Errors::ClientError raised in DecisionReviews::V1::Service", :code=>"DR_422"}'
  end

  let(:response_error_body) do
    {
      'errors' => [{ 'title' => 'Missing required fields',
                     'detail' => 'One or more expected fields were not found',
                     'code' => '145',
                     'source' => { 'pointer' => '/data/attributes' },
                     'status' => '422',
                     'meta' => { 'missing_fields' => ['form5103Acknowledged'] } }]
    }
  end

  before { sign_in_as(user) }

  describe '#create' do
    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?',
                                   'DecisionReviews::V1::SupplementalClaimsController#create exception % (SC_V1)'
    end

    subject do
      post '/decision_reviews/v1/supplemental_claims',
           params: VetsJsonSchema::EXAMPLES.fetch('SC-CREATE-REQUEST-BODY_V1').to_json,
           headers:
    end

    it 'creates a supplemental claim' do
      VCR.use_cassette('decision_review/SC-CREATE-RESPONSE-200_V1') do
        # Create an InProgressForm
        in_progress_form = create(:in_progress_form, user_uuid: user.uuid, form_id: '20-0995')
        expect(in_progress_form).not_to be_nil
        previous_appeal_submission_ids = AppealSubmission.all.pluck :submitted_appeal_uuid

        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(success_log_args)
        allow(StatsD).to receive(:increment)
        expect(StatsD).to receive(:increment).with('decision_review.form_995.overall_claim_submission.success')

        subject
        expect(response).to be_successful
        parsed_response = JSON.parse(response.body)
        id = parsed_response['data']['id']
        expect(previous_appeal_submission_ids).not_to include id
        appeal_submission = AppealSubmission.find_by(submitted_appeal_uuid: id)
        expect(appeal_submission.type_of_appeal).to eq('SC')
        # InProgressForm should be destroyed after successful submission
        in_progress_form = InProgressForm.find_by(user_uuid: user.uuid, form_id: '20-0995')
        expect(in_progress_form).to be_nil
        # SavedClaim should be created with request data
        saved_claim = SavedClaim::SupplementalClaim.find_by(guid: id)
        expect(saved_claim.form).to eq(VetsJsonSchema::EXAMPLES.fetch('SC-CREATE-REQUEST-BODY_V1').to_json)
        expect(saved_claim.uploaded_forms).to be_empty
      end
    end

    it 'adds to the PersonalInformationLog when an exception is thrown' do
      VCR.use_cassette('decision_review/SC-CREATE-RESPONSE-422_V1') do
        expect(personal_information_logs.count).to be 0
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with(error_log_args)
        allow(StatsD).to receive(:increment)
        expect(StatsD).to receive(:increment).with('decision_review.form_995.overall_claim_submission.failure')

        subject
        expect(response).to have_http_status(:unprocessable_entity)
        expect(personal_information_logs.count).to be >= 1
        pil = personal_information_logs.first
        %w[
          first_name last_name birls_id icn edipi mhv_correlation_id
          participant_id vet360_id ssn assurance_level birth_date
        ].each { |key| expect(pil.data['user'][key]).to be_truthy }
        %w[message backtrace].each { |key| expect(pil.data['error'][key]).to be_truthy }
        expect(pil.data['additional_data']['request']['body']).not_to be_empty
      end
    end
  end

  describe '#create with 4142' do
    let(:params) { VetsJsonSchema::EXAMPLES.fetch('SC-CREATE-REQUEST-BODY-FOR-VA-GOV').deep_dup }

    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?',
                                   'DecisionReviews::V1::SupplementalClaimsController#create exception % (SC_V1)'
    end

    context 'when schema validation fails' do
      let(:invalid_params) { VetsJsonSchema::EXAMPLES.fetch('SC-CREATE-REQUEST-BODY-FOR-VA-GOV').deep_dup }

      before do
        allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_call_original
        allow(Flipper).to receive(:enabled?).with(:decision_review_form4142_validate_schema).and_return(true)
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
      end

      it 'logs the error and increments the StatsD metric' do
        VCR.use_cassette('decision_review/SC-CREATE-RESPONSE-WITH-4142-200_V1') do
          invalid_params['form4142']['providerFacility'] = nil
          post('/decision_reviews/v1/supplemental_claims',
               params: invalid_params.to_json,
               headers:)
          expect do
            DecisionReviews::Form4142Submit.drain
          end.to raise_error(Processors::Form4142ValidationError, anything)
          expect(Rails.logger).to have_received(:error).with('Form 4142 failed validation', anything)
          expect(StatsD).to have_received(:increment)
            .with('api.decision_review.process_form4142_submission.fail',
                  tags: ['error:ProcessorsForm4142ValidationError'])
          expect(StatsD).to have_received(:increment).with('worker.decision_review.form4142_submit.error')
        end
      end
    end

    context 'when tracking 4142' do
      subject do
        post '/decision_reviews/v1/supplemental_claims',
             params: params.to_json,
             headers:
      end

      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_call_original
        allow(Flipper).to receive(:enabled?).with(:decision_review_form4142_validate_schema).and_return(true)
      end

      it 'creates a supplemental claim and queues and saves a 4142 form when 4142 info is provided' do
        VCR.use_cassette('decision_review/SC-CREATE-RESPONSE-WITH-4142-200_V1') do
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
            VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
              previous_appeal_submission_ids = AppealSubmission.all.pluck :submitted_appeal_uuid
              expect { subject }.to change(DecisionReviews::Form4142Submit.jobs, :size).by(1)
              expect(response).to be_successful
              parsed_response = JSON.parse(response.body)
              id = parsed_response['data']['id']
              expect(previous_appeal_submission_ids).not_to include id
              appeal_submission = AppealSubmission.find_by(submitted_appeal_uuid: id)
              expect(appeal_submission.type_of_appeal).to eq('SC')
              expect do
                DecisionReviews::Form4142Submit.drain
              end.to change(DecisionReviews::Form4142Submit.jobs, :size).by(-1)

              # SavedClaim should be created with request data and list of uploaded forms
              request_body = JSON.parse(VetsJsonSchema::EXAMPLES.fetch('SC-CREATE-REQUEST-BODY-FOR-VA-GOV').to_json)
              saved_claim = SavedClaim::SupplementalClaim.find_by(guid: id)
              expect(saved_claim.form).to eq(request_body.to_json)
              expect(saved_claim.uploaded_forms).to contain_exactly '21-4142'

              # SecondaryAppealForm should be created with 4142 data and user data
              expected_form4142_data = VetsJsonSchema::EXAMPLES.fetch('SC-CREATE-REQUEST-BODY-FOR-VA-GOV')['form4142']
              veteran_data = {
                'vaFileNumber' => '796111863',
                'veteranSocialSecurityNumber' => '796111863',
                'veteranFullName' => {
                  'first' => 'abraham',
                  'middle' => nil,
                  'last' => 'lincoln'
                },
                'veteranDateOfBirth' => '1809-02-12',
                'veteranAddress' => { 'addressLine1' => '123  Main St', 'city' => 'New York', 'countryCodeISO2' => 'US',
                                      'zipCode5' => '30012', 'country' => 'USA', 'postalCode' => '30012',
                                      'street' => '123  Main St', 'street2' => nil, 'state' => nil },
                'email' => 'josie@example.com',
                'veteranPhone' => '5558001111'
              }
              expected_form4142_data_with_user = veteran_data.merge(expected_form4142_data)
              saved4142 = SecondaryAppealForm.last
              saved_4142_json = JSON.parse(saved4142.form)
              expect(saved_4142_json).to eq(expected_form4142_data_with_user)
              expect(saved4142.form_id).to eq('21-4142')
              expect(saved4142.appeal_submission.id).to eq(appeal_submission.id)
            end
          end
        end
      end
    end
  end

  describe '#create with uploads' do
    # Create evidence files objs

    subject do
      post '/decision_reviews/v1/supplemental_claims',
           params: example_payload.to_json,
           headers:
    end

    let(:example_payload) { VetsJsonSchema::EXAMPLES.fetch('SC-CREATE-REQUEST-BODY-FOR-VA-GOV') }

    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?',
                                   'DecisionReviews::V1::SupplementalClaimsController#create exception % (SC_V1)'
    end

    context 'when valid data is submitted' do
      it 'creates a supplemental claim and queues evidence jobs when additionalDocuments info is provided' do
        VCR.use_cassette('decision_review/SC-CREATE-RESPONSE-WITH-UPLOADS-200_V1') do
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
            VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
              VCR.use_cassette('decision_review/SC-GET-UPLOAD-URL-200_V1') do
                expect { subject }.to change(DecisionReviews::SubmitUpload.jobs, :size).by(2)
                expect(response).to be_successful
                parsed_response = JSON.parse(response.body)
                id = parsed_response['data']['id']
                appeal_submission = AppealSubmission.find_by(submitted_appeal_uuid: id)
                expect(appeal_submission.type_of_appeal).to eq('SC')
              end
            end
          end
        end
      end
    end

    context 'when an error occurs in the transaction' do
      shared_examples 'rolledback transaction' do |model|
        before do
          allow_any_instance_of(model).to receive(:save!).and_raise(ActiveModel::Error) # stub a model error
        end

        it 'rollsback transaction' do
          VCR.use_cassette('decision_review/SC-CREATE-RESPONSE-WITH-UPLOADS-200_V1') do
            expect(subject).to eq 500

            # check that transaction rolled back / records were not persisted / evidence upload job was not queued up
            expect(AppealSubmission.count).to eq 0
            expect(AppealSubmissionUpload.count).to eq 0
            expect(DecisionReviews::SubmitUpload).not_to have_enqueued_sidekiq_job(anything)
            expect(SavedClaim.count).to eq 0
            expect(SecondaryAppealForm.count).to eq 0
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
