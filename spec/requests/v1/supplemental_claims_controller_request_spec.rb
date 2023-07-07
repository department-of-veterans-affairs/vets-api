# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V1::SupplementalClaimsController do
  let(:user) { build(:user, :loa3) }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }

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
        previous_appeal_submission_ids = AppealSubmission.all.pluck :submitted_appeal_uuid
        subject
        expect(response).to be_successful
        parsed_response = JSON.parse(response.body)
        id = parsed_response['data']['id']
        expect(previous_appeal_submission_ids).not_to include id
        appeal_submission = AppealSubmission.find_by(submitted_appeal_uuid: id)
        expect(appeal_submission.type_of_appeal).to eq('SC')
      end
    end

    it 'adds to the PersonalInformationLog when an exception is thrown' do
      VCR.use_cassette('decision_review/SC-CREATE-RESPONSE-422_V1') do
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
