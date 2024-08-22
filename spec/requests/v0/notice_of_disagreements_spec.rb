# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe 'V0::NoticeOfDisagreements', type: :request do
  let(:user) { build(:user, :loa3) }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }

  before { sign_in_as(user) }

  describe '#create' do
    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?', 'V0::NoticeOfDisagreementsController#create exception % (NOD)'
    end

    subject { post '/v0/notice_of_disagreements', params: body.to_json, headers: }

    let(:body) do
      JSON.parse Rails.root.join('spec', 'fixtures', 'notice_of_disagreements',
                                 'valid_NOD_create_request.json').read
    end

    it 'creates an NOD' do
      VCR.use_cassette('decision_review/NOD-CREATE-RESPONSE-200') do
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
                                                      },
                                                      version_number: 'v1'
                                                    })
        allow(StatsD).to receive(:increment)
        expect(StatsD).to receive(:increment).with('decision_review.form_10182.overall_claim_submission.success')
        expect(StatsD).to receive(:increment).with('nod_evidence_upload.v1.queued')
        previous_appeal_submission_ids = AppealSubmission.all.pluck :submitted_appeal_uuid
        subject
        expect(response).to be_successful
        parsed_response = JSON.parse(response.body)
        id = parsed_response['data']['id']
        expect(previous_appeal_submission_ids).not_to include id
        appeal_submission = AppealSubmission.find_by(submitted_appeal_uuid: id)
        expect(appeal_submission.board_review_option).to eq('evidence_submission')
        expect(appeal_submission.upload_metadata).to eq({
          'veteranFirstName' => user.first_name,
          'veteranLastName' => user.last_name,
          'zipCode' => user.postal_code,
          'fileNumber' => user.ssn.to_s.strip,
          'source' => 'Vets.gov',
          'businessLine' => 'BVA'
        }.to_json)
        appeal_submission_uploads = AppealSubmissionUpload.where(appeal_submission:)
        expect(appeal_submission_uploads.count).to eq 1
        expect(DecisionReview::SubmitUpload).to have_enqueued_sidekiq_job(appeal_submission_uploads.first.id)
        # SavedClaim should be created with request data
        saved_claim = SavedClaim::NoticeOfDisagreement.find_by(guid: id)
        expect(JSON.parse(saved_claim.form)).to eq(body)
      end
    end

    it 'adds to the PersonalInformationLog when an exception is thrown' do
      VCR.use_cassette('decision_review/NOD-CREATE-RESPONSE-422') do
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with({
                                                       message: 'Overall claim submission failure!',
                                                       user_uuid: user.uuid,
                                                       action: 'Overall claim submission',
                                                       form_id: '10182',
                                                       upstream_system: nil,
                                                       downstream_system: 'Lighthouse',
                                                       is_success: false,
                                                       http: {
                                                         status_code: 422,
                                                         body: anything
                                                       },
                                                       version_number: 'v1'
                                                     })
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
      end
    end
  end

  describe '#show' do
    subject { get "/v0/notice_of_disagreements/#{uuid}" }

    let(:uuid) { '1234567a-89b0-123c-d456-789e01234f56' }

    it 'shows an HLR' do
      VCR.use_cassette('decision_review/NOD-SHOW-RESPONSE-200') do
        subject
        expect(response).to be_successful
        expect(JSON.parse(response.body)['data']['id']).to eq uuid
      end
    end
  end
end
