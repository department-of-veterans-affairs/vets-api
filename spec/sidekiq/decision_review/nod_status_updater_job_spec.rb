# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe DecisionReview::NodStatusUpdaterJob, type: :job do
  subject { described_class }

  let(:service) { instance_double(DecisionReviewV1::Service) }

  let(:guid1) { SecureRandom.uuid }
  let(:guid2) { SecureRandom.uuid }
  let(:guid3) { SecureRandom.uuid }

  let(:response_complete) do
    response = JSON.parse(VetsJsonSchema::EXAMPLES.fetch('NOD-SHOW-RESPONSE-200_V2').to_json) # deep copy
    response['data']['attributes']['status'] = 'complete'
    instance_double(Faraday::Response, body: response)
  end

  let(:response_pending) do
    instance_double(Faraday::Response, body: VetsJsonSchema::EXAMPLES.fetch('NOD-SHOW-RESPONSE-200_V2'))
  end

  let(:response_error) do
    response = JSON.parse(VetsJsonSchema::EXAMPLES.fetch('SC-SHOW-RESPONSE-200_V2').to_json) # deep copy
    response['data']['attributes']['status'] = 'error'
    instance_double(Faraday::Response, body: response)
  end

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

  before do
    allow(DecisionReviewV1::Service).to receive(:new).and_return(service)
  end

  describe 'perform' do
    context 'with flag enabled', :aggregate_failures do
      before do
        Flipper.enable :decision_review_saved_claim_nod_status_updater_job_enabled
        allow(StatsD).to receive(:increment)
      end

      context 'SavedClaim records are present and there are no evidence uploads' do
        before do
          SavedClaim::NoticeOfDisagreement.create(guid: guid1, form: '{}')
          SavedClaim::NoticeOfDisagreement.create(guid: guid2, form: '{}')
          SavedClaim::NoticeOfDisagreement.create(guid: guid3, form: '{}', delete_date: DateTime.new(2024, 2, 1).utc)
          SavedClaim::HigherLevelReview.create(form: '{}')
          SavedClaim::SupplementalClaim.create(form: '{}')
        end

        it 'updates SavedClaim::NoticeOfDisagreement delete_date for completed records without a delete_date' do
          expect(service).to receive(:get_notice_of_disagreement).with(guid1).and_return(response_complete)
          expect(service).to receive(:get_notice_of_disagreement).with(guid2).and_return(response_pending)
          expect(service).not_to receive(:get_notice_of_disagreement).with(guid3)

          expect(service).not_to receive(:get_higher_level_review)
          expect(service).not_to receive(:get_supplemental_claim)

          frozen_time = DateTime.new(2024, 1, 1).utc

          Timecop.freeze(frozen_time) do
            subject.new.perform

            claim1 = SavedClaim::NoticeOfDisagreement.find_by(guid: guid1)
            expect(claim1.delete_date).to eq frozen_time + 59.days
            expect(claim1.metadata).to include 'complete'
            expect(claim1.metadata_updated_at).to eq frozen_time

            claim2 = SavedClaim::NoticeOfDisagreement.find_by(guid: guid2)
            expect(claim2.delete_date).to be_nil
            expect(claim2.metadata).to include 'pending'
            expect(claim2.metadata_updated_at).to eq frozen_time
          end

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_nod_status_updater.processing_records', 2).exactly(1).time
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_nod_status_updater.delete_date_update').exactly(1).time
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_nod_status_updater.status', tags: ['status:pending'])
            .exactly(1).time
        end
      end

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

      context 'SavedClaim record with previous metadata' do
        before do
          allow(Rails.logger).to receive(:info)
        end

        let(:guid4) { SecureRandom.uuid }
        let(:guid5) { SecureRandom.uuid }

        let(:upload_id) { SecureRandom.uuid }
        let(:upload_id2) { SecureRandom.uuid }
        let(:upload_id3) { SecureRandom.uuid }

        let(:metadata1) do
          {
            'status' => 'submitted',
            'uploads' => [
              {
                'status' => 'error',
                'detail' => 'Invalid PDF',
                'id' => upload_id
              }
            ]
          }
        end

        let(:metadata2) do
          {
            'status' => 'submitted',
            'uploads' => [
              {
                'status' => 'pending',
                'detail' => nil,
                'id' => upload_id2
              },
              {
                'status' => 'processing',
                'detail' => nil,
                'id' => upload_id3
              }
            ]
          }
        end

        it 'does not increment metrics for unchanged form status or existing final statuses' do
          SavedClaim::NoticeOfDisagreement.create(guid: guid1, form: '{}',
                                                  metadata: '{"status":"error","uploads":[]}')
          SavedClaim::NoticeOfDisagreement.create(guid: guid2, form: '{}',
                                                  metadata: '{"status":"submitted","uploads":[]}')
          SavedClaim::NoticeOfDisagreement.create(guid: guid3, form: '{}',
                                                  metadata: '{"status":"pending","uploads":[]}')
          SavedClaim::NoticeOfDisagreement.create(guid: guid4, form: '{}',
                                                  metadata: '{"status":"complete","uploads":[]}')
          SavedClaim::NoticeOfDisagreement.create(guid: guid5, form: '{}',
                                                  metadata: '{"status":"DR_404","uploads":[]}')

          expect(service).not_to receive(:get_notice_of_disagreement).with(guid1)
          expect(service).to receive(:get_notice_of_disagreement).with(guid2).and_return(response_error)
          expect(service).to receive(:get_notice_of_disagreement).with(guid3).and_return(response_pending)
          expect(service).not_to receive(:get_notice_of_disagreement).with(guid4)
          expect(service).not_to receive(:get_notice_of_disagreement).with(guid5)

          subject.new.perform

          claim2 = SavedClaim::NoticeOfDisagreement.find_by(guid: guid2)
          expect(claim2.delete_date).to be_nil
          expect(claim2.metadata).to include 'error'

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_nod_status_updater.status', tags: ['status:error'])
            .exactly(1).time
          expect(StatsD).not_to have_received(:increment)
            .with('worker.decision_review.saved_claim_nod_status_updater.status', tags: ['status:pending'])

          expect(Rails.logger).not_to have_received(:info)
            .with('DecisionReview::SavedClaimNodStatusUpdaterJob form status error', guid: guid1)
          expect(Rails.logger).to have_received(:info)
            .with('DecisionReview::SavedClaimNodStatusUpdaterJob form status error', guid: guid2)
          expect(StatsD).to have_received(:increment)
            .with('silent_failure', tags: ['service:board-appeal', 'function: form submission to Lighthouse'])
            .exactly(1).time
        end

        it 'does not increment metrics for unchanged evidence status or existing final statuses' do
          SavedClaim::NoticeOfDisagreement.create(guid: guid1, form: '{}', metadata: metadata1.to_json)
          appeal_submission = create(:appeal_submission, submitted_appeal_uuid: guid1)
          create(:appeal_submission_upload, appeal_submission:, lighthouse_upload_id: upload_id)

          SavedClaim::NoticeOfDisagreement.create(guid: guid2, form: '{}', metadata: metadata2.to_json)
          appeal_submission2 = create(:appeal_submission, submitted_appeal_uuid: guid2)
          create(:appeal_submission_upload, appeal_submission: appeal_submission2, lighthouse_upload_id: upload_id2)
          create(:appeal_submission_upload, appeal_submission: appeal_submission2, lighthouse_upload_id: upload_id3)

          expect(service).to receive(:get_notice_of_disagreement).with(guid1).and_return(response_pending)
          expect(service).to receive(:get_notice_of_disagreement).with(guid2).and_return(response_error)

          expect(service).not_to receive(:get_notice_of_disagreement_upload).with(guid: upload_id)
          expect(service).to receive(:get_notice_of_disagreement_upload).with(guid: upload_id2)
                                                                        .and_return(upload_response_error)
          expect(service).to receive(:get_notice_of_disagreement_upload).with(guid: upload_id3)
                                                                        .and_return(upload_response_processing)

          subject.new.perform

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_nod_status_updater_upload.status', tags: ['status:error'])
            .exactly(1).times
          expect(StatsD).not_to have_received(:increment)
            .with('worker.decision_review.saved_claim_nod_status_updater_upload.status', tags: ['status:processing'])

          expect(Rails.logger).not_to have_received(:info)
            .with('DecisionReview::SavedClaimNodStatusUpdaterJob evidence status error',
                  guid: anything, lighthouse_upload_id: upload_id, detail: anything)
          expect(Rails.logger).to have_received(:info)
            .with('DecisionReview::SavedClaimNodStatusUpdaterJob evidence status error',
                  guid: guid2, lighthouse_upload_id: upload_id2, detail: 'Invalid PDF')
          expect(StatsD).to have_received(:increment)
            .with('silent_failure', tags: ['service:board-appeal',
                                           'function: evidence submission to Lighthouse'])
            .exactly(1).time
        end
      end

      context 'Retrieving SavedClaim records fails' do
        before do
          allow(SavedClaim::NoticeOfDisagreement).to receive(:where).and_raise(ActiveRecord::ConnectionTimeoutError)
          allow(Rails.logger).to receive(:error)
        end

        it 'rescues the error and logs' do
          subject.new.perform

          expect(Rails.logger).to have_received(:error)
            .with('DecisionReview::SavedClaimNodStatusUpdaterJob error', anything)
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_nod_status_updater.error').once
        end
      end

      context 'an error occurs while processing' do
        before do
          allow(Rails.logger).to receive(:error)
          allow(service).to receive(:get_notice_of_disagreement).and_raise(exception)

          SavedClaim::NoticeOfDisagreement.create(guid: guid1, form: '{}')
          SavedClaim::NoticeOfDisagreement.create(guid: guid2, form: '{}')
        end

        context 'and it is a temporary error' do
          let(:exception) { DecisionReviewV1::ServiceException.new(key: 'DR_504') }

          it 'handles request errors and increments the statsd metric' do
            subject.new.perform

            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.saved_claim_nod_status_updater.error').exactly(2).times
          end
        end

        context 'and it is a 404 error' do
          let(:exception) { DecisionReviewV1::ServiceException.new(key: 'DR_404') }

          it 'updates the status of the record' do
            subject.new.perform

            nod1 = SavedClaim::NoticeOfDisagreement.find_by(guid: guid1)
            metadata1 = JSON.parse(nod1.metadata)
            expect(metadata1['status']).to eq 'DR_404'

            nod2 = SavedClaim::NoticeOfDisagreement.find_by(guid: guid2)
            metadata2 = JSON.parse(nod2.metadata)
            expect(metadata2['status']).to eq 'DR_404'

            expect(Rails.logger).to have_received(:error)
              .with('DecisionReview::SavedClaimNodStatusUpdaterJob error', { guid: anything, message: anything })
              .exactly(2).times
          end
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
