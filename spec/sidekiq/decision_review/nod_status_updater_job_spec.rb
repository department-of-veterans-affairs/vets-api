# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'
require 'sidekiq/decision_review/shared_examples_for_status_updater_jobs'

RSpec.describe DecisionReview::NodStatusUpdaterJob, type: :job do
  subject { described_class }

  include_context 'status updater job context', SavedClaim::NoticeOfDisagreement

  let(:upload_response_vbms) do
    response = JSON.parse(File.read('spec/fixtures/notice_of_disagreements/NOD_upload_show_response_200.json'))
    instance_double(Faraday::Response, body: response)
  end

  let(:upload_response_processing) do
    response = JSON.parse(File.read('spec/fixtures/notice_of_disagreements/NOD_upload_show_response_200.json'))
    response['data']['attributes']['status'] = 'processing'
    instance_double(Faraday::Response, body: response)
  end

  let(:upload_response_error) do
    response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_upload_show_response_200.json'))
    response['data']['attributes']['status'] = 'error'
    response['data']['attributes']['detail'] = 'Invalid PDF'
    instance_double(Faraday::Response, body: response)
  end

  describe 'perform' do
    context 'with flag enabled', :aggregate_failures do
      before do
        Flipper.enable :decision_review_saved_claim_nod_status_updater_job_enabled
      end

      include_examples 'status updater job with base forms', SavedClaim::NoticeOfDisagreement

      context 'SavedClaim records are present with completed status in LH and have associated evidence uploads' do
        let(:upload_id) { SecureRandom.uuid }
        let(:upload_id2) { SecureRandom.uuid }
        let(:upload_id3) { SecureRandom.uuid }
        let(:upload_id4) { SecureRandom.uuid }

        before do
          allow(Rails.logger).to receive(:info)

          SavedClaim::NoticeOfDisagreement.create(guid: guid1, form: '{}')
          SavedClaim::NoticeOfDisagreement.create(guid: guid2, form: '{}')
          SavedClaim::NoticeOfDisagreement.create(guid: guid3, form: '{}')

          appeal_submission = create(:appeal_submission, submitted_appeal_uuid: guid1)
          create(:appeal_submission_upload, appeal_submission:, lighthouse_upload_id: upload_id)

          appeal_submission2 = create(:appeal_submission, submitted_appeal_uuid: guid2)
          create(:appeal_submission_upload, appeal_submission: appeal_submission2, lighthouse_upload_id: upload_id2)

          # One upload vbms, other one still processing
          appeal_submission3 = create(:appeal_submission, submitted_appeal_uuid: guid3)
          create(:appeal_submission_upload, appeal_submission: appeal_submission3, lighthouse_upload_id: upload_id3)
          create(:appeal_submission_upload, appeal_submission: appeal_submission3, lighthouse_upload_id: upload_id4)
        end

        it 'only sets delete_date for SavedClaim::NoticeOfDisagreement with all attachments in vbms status' do
          expect(service).to receive(:get_notice_of_disagreement_upload).with(guid: upload_id)
                                                                        .and_return(upload_response_vbms)
          expect(service).to receive(:get_notice_of_disagreement_upload).with(guid: upload_id2)
                                                                        .and_return(upload_response_processing)
          expect(service).to receive(:get_notice_of_disagreement_upload).with(guid: upload_id3)
                                                                        .and_return(upload_response_vbms)
          expect(service).to receive(:get_notice_of_disagreement_upload).with(guid: upload_id4)
                                                                        .and_return(upload_response_processing)

          expect(service).to receive(:get_notice_of_disagreement).with(guid1).and_return(response_complete)
          expect(service).to receive(:get_notice_of_disagreement).with(guid2).and_return(response_complete)
          expect(service).to receive(:get_notice_of_disagreement).with(guid3).and_return(response_complete)

          frozen_time = DateTime.new(2024, 1, 1).utc

          Timecop.freeze(frozen_time) do
            subject.new.perform

            claim1 = SavedClaim::NoticeOfDisagreement.find_by(guid: guid1)
            expect(claim1.delete_date).to eq frozen_time + 59.days
            expect(claim1.metadata_updated_at).to eq frozen_time
            expect(claim1.metadata).to include 'complete'
            expect(claim1.metadata).to include 'vbms'

            claim2 = SavedClaim::NoticeOfDisagreement.find_by(guid: guid2)
            expect(claim2.delete_date).to be_nil
            expect(claim2.metadata_updated_at).to eq frozen_time
            expect(claim2.metadata).to include 'complete'
            expect(claim2.metadata).to include 'processing'

            claim3 = SavedClaim::NoticeOfDisagreement.find_by(guid: guid3)
            expect(claim3.delete_date).to be_nil
            expect(claim3.metadata_updated_at).to eq frozen_time

            metadata3 = JSON.parse(claim3.metadata)
            expect(metadata3['status']).to eq 'complete'
            expect(metadata3['uploads'].pluck('id', 'status'))
              .to contain_exactly([upload_id3, 'vbms'], [upload_id4, 'processing'])
          end

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_nod_status_updater.processing_records', 3).exactly(1).time
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_nod_status_updater.delete_date_update').exactly(1).time
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_nod_status_updater.status', tags: ['status:complete'])
            .exactly(2).times
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_nod_status_updater_upload.status', tags: ['status:vbms'])
            .exactly(2).times
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_nod_status_updater_upload.status', tags: ['status:processing'])
            .exactly(2).times
          expect(Rails.logger).not_to have_received(:info)
            .with('DecisionReview::SavedClaimNodStatusUpdaterJob evidence status error', anything)
        end
      end
    end

    context 'with flag disabled' do
      before do
        Flipper.disable :decision_review_saved_claim_nod_status_updater_job_enabled
      end

      it 'does not query SavedClaim::HigherLevelReview records' do
        expect(SavedClaim::NoticeOfDisagreement).not_to receive(:where)

        subject.new.perform
      end
    end
  end
end
