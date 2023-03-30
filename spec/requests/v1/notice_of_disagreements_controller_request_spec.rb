# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V1::NoticeOfDisagreementsController do
  let(:user) do
    build(:user,
          :loa3,
          mhv_correlation_id: 'some-mhv_correlation_id',
          birls_id: 'some-birls_id',
          participant_id: 'some-participant_id',
          vet360_id: 'some-vet360_id')
  end
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }

  before { sign_in_as(user) }

  describe '#create' do
    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?',
                                   'V1::NoticeOfDisagreementsController#create exception % (NOD_V1)'
    end

    subject do
      post '/v1/notice_of_disagreements',
           params: VetsJsonSchema::EXAMPLES.fetch('NOD-CREATE-REQUEST-BODY_V1').to_json,
           headers:
    end

    it 'creates an NOD' do
      VCR.use_cassette('decision_review/NOD-CREATE-RESPONSE-200_V1') do
        previous_appeal_submission_ids = AppealSubmission.all.pluck :submitted_appeal_uuid
        subject
        expect(response).to be_successful
        parsed_response = JSON.parse(response.body)
        id = parsed_response['data']['id']
        expect(previous_appeal_submission_ids).not_to include id
        appeal_submission = AppealSubmission.find_by(submitted_appeal_uuid: id)
        expect(appeal_submission.type_of_appeal).to eq('NOD')
      end
    end

    it 'adds to the PersonalInformationLog when an exception is thrown' do
      VCR.use_cassette('decision_review/NOD-CREATE-RESPONSE-422_V1') do
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
end
