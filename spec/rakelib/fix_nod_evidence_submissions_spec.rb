# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe 'fix NOD evidence submission rake task', type: :request do
  let(:user) { build(:disabilities_compensation_user) }

  let(:form_attachment1) { create(:preneed_attachment) }
  let(:form_attachment2) { create(:preneed_attachment) }
  let(:form_attachment3) { create(:preneed_attachment) }

  let(:form_data_single_upload) do
    {
      'data' => {
        'attributes' => {
          'veteran' => { 'address' => { 'zipCode5' => '90210' } }
        }
      },
      'nodUploads' => [{ 'confirmationCode' => form_attachment1.guid }]
    }
  end

  let(:form_data_multi_upload) do
    {
      'data' => {
        'attributes' => {
          'veteran' => { 'address' => { 'zipCode5' => '90210' } }
        }
      },
      'nodUploads' => [
        { 'confirmationCode' => form_attachment2.guid },
        { 'confirmationCode' => form_attachment3.guid }
      ]
    }
  end

  let(:auth_headers) do
    {
      'X-VA-First-Name' => 'Jane',
      'X-VA-Last-Name' => 'Doe',
      'X-VA-File-Number' => '111222333'
    }
  end

  let(:expected_upload_metadata) do
    {
      'veteranFirstName' => 'Jane',
      'veteranLastName' => 'Doe',
      'zipCode' => '90210',
      'fileNumber' => '111222333',
      'source' => 'va.gov',
      'businessLine' => 'BVA'
    }.to_json
  end

  let!(:appeals_api_nod_submission_v2_single_upload) do
    AppealsApi::NoticeOfDisagreement.create(
      api_version: 'V2',
      board_review_option: 'evidence_submission',
      form_data: form_data_single_upload,
      auth_headers:
    )
  end

  let!(:appeals_api_nod_submission_v2_multi_upload) do
    AppealsApi::NoticeOfDisagreement.create(
      api_version: 'V2',
      board_review_option: 'evidence_submission',
      form_data: form_data_multi_upload,
      auth_headers:
    )
  end

  let!(:appeal_submission_single_upload) do
    AppealSubmission.create(
      submitted_appeal_uuid: appeals_api_nod_submission_v2_single_upload.id,
      type_of_appeal: 'NOD',
      user_uuid: user.uuid
    )
  end

  let!(:appeal_submission_multi_upload) do
    AppealSubmission.create(
      submitted_appeal_uuid: appeals_api_nod_submission_v2_multi_upload.id,
      type_of_appeal: 'NOD',
      user_uuid: user.uuid
    )
  end

  before :all do
    Rake.application.rake_require '../rakelib/fix_nod_evidence_submissions'
    Rake::Task.define_task(:environment)
  end

  describe 'rake decision_reviews:fix_nod_evidence_submissions' do
    let :run_rake_task do
      Rake::Task['decision_reviews:fix_nod_evidence_submissions'].reenable
      Rake.application.invoke_task 'decision_reviews:fix_nod_evidence_submissions'
    end

    it 'creates missing AppealSubmissionUpload records' do
      expect(DecisionReview::SubmitUpload).to receive(:perform_async)
                                          .exactly(3)
        .times
        .and_return('job_id_1', 'job_id_2', 'job_id_3')

      appeal_submission_upload_for_single_upload_nod = AppealSubmissionUpload.where(
        decision_review_evidence_attachment_guid: form_attachment1.guid,
        appeal_submission_id: appeal_submission_single_upload.id
      )

      appeal_submission_upload_for_multi_upload_nod = AppealSubmissionUpload.where(
        decision_review_evidence_attachment_guid: [form_attachment2.guid, form_attachment3.guid],
        appeal_submission_id: appeal_submission_multi_upload.id
      )

      expect(appeal_submission_upload_for_single_upload_nod).to be_empty
      expect(appeal_submission_upload_for_multi_upload_nod).to be_empty

      logger_msg = {
        message: 'Successfully enqueued evidence upload jobs', upload_job_ids: %w[
          job_id_1 job_id_2 job_id_3
        ]
      }

      expect(Rails.logger).to receive(:info).with(logger_msg)
      expect { run_rake_task }.not_to raise_error

      appeal_submission_upload_for_single_upload_nod.reload
      appeal_submission_upload_for_multi_upload_nod.reload

      expect(appeal_submission_upload_for_single_upload_nod.count).to eq 1
      expect(appeal_submission_upload_for_multi_upload_nod.count).to eq 2
    end

    it 'updates AppealSubmissions with missing `board_review_option` and `upload_metadata`' do
      expect(appeal_submission_single_upload.board_review_option).to be_nil
      expect(appeal_submission_multi_upload.board_review_option).to be_nil

      run_rake_task

      appeal_submission_single_upload.reload
      appeal_submission_multi_upload.reload

      expect(appeal_submission_single_upload.board_review_option).to eq 'evidence_submission'
      expect(appeal_submission_single_upload.upload_metadata).to eq expected_upload_metadata
      expect(appeal_submission_multi_upload.board_review_option).to eq 'evidence_submission'
      expect(appeal_submission_multi_upload.upload_metadata).to eq expected_upload_metadata
    end

    it 'logs an error message with the AppealsApi::NoticeOfDisagreement id' do
      appeal_submission_single_upload.update(submitted_appeal_uuid: 'something else')

      expected_error_message = "Error while attempting to complete NOD evidence submission: Couldn't find AppealSubmission"
      expected_appeals_api_nod_id = appeals_api_nod_submission_v2_single_upload.id
      expect(Rails.logger).to receive(:error) do |error_log|
        expect(error_log[:message]).to include(expected_error_message)
        expect(error_log[:appeals_api_nod_id]).to include(expected_appeals_api_nod_id)
        expect(error_log[:backtrace]).to be_an(Array)
      end
      run_rake_task
    end
  end
end
