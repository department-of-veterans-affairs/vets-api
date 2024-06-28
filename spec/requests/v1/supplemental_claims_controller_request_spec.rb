# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V1::SupplementalClaimsController do
  let(:user) { build(:user, :loa3) }
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
        body: anything
      }
    }
  end

  before { sign_in_as(user) }

  describe '#create' do
    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?',
                                   'V1::SupplementalClaimsController#create exception % (SC_V1)'
    end

    subject do
      post '/v1/supplemental_claims',
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

  describe '#create with 4142' do
    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?',
                                   'V1::SupplementalClaimsController#create exception % (SC_V1)'
    end

    subject do
      post '/v1/supplemental_claims',
           params: VetsJsonSchema::EXAMPLES.fetch('SC-CREATE-REQUEST-BODY-FOR-VA-GOV').to_json,
           headers:
    end

    before do
      Flipper.disable :decision_review_sc_use_lighthouse_api_for_form4142
    end

    it 'creates a supplemental claim and queues a 4142 form when 4142 info is provided' do
      VCR.use_cassette('decision_review/SC-CREATE-RESPONSE-WITH-4142-200_V1') do
        VCR.use_cassette('central_mail/submit_4142') do
          previous_appeal_submission_ids = AppealSubmission.all.pluck :submitted_appeal_uuid
          expect { subject }.to change(DecisionReview::Form4142Submit.jobs, :size).by(1)
          expect(response).to be_successful
          parsed_response = JSON.parse(response.body)
          id = parsed_response['data']['id']
          expect(previous_appeal_submission_ids).not_to include id
          appeal_submission = AppealSubmission.find_by(submitted_appeal_uuid: id)
          expect(appeal_submission.type_of_appeal).to eq('SC')
          expect { DecisionReview::Form4142Submit.drain }.to change(DecisionReview::Form4142Submit.jobs, :size).by(-1)
        end
      end
    end
  end

  describe '#create with uploads' do
    # Create evidence files objs

    subject do
      post '/v1/supplemental_claims',
           params: example_payload.to_json,
           headers:
    end

    let(:example_payload) { VetsJsonSchema::EXAMPLES.fetch('SC-CREATE-REQUEST-BODY-FOR-VA-GOV') }

    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?',
                                   'V1::SupplementalClaimsController#create exception % (SC_V1)'
    end

    it 'creates a supplemental claim and queues evidence jobs when additionalDocuments info is provided' do
      VCR.use_cassette('decision_review/SC-CREATE-RESPONSE-WITH-UPLOADS-200_V1') do
        VCR.use_cassette('central_mail/submit_4142') do
          VCR.use_cassette('decision_review/SC-GET-UPLOAD-URL-200_V1') do
            expect { subject }.to change(DecisionReview::SubmitUpload.jobs, :size).by(2)
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
