# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe DecisionReview::ScStatusUpdaterJob, type: :job do
  subject { described_class }

  let(:service) { instance_double(DecisionReviewV1::Service) }

  let(:guid1) { SecureRandom.uuid }
  let(:guid2) { SecureRandom.uuid }
  let(:guid3) { SecureRandom.uuid }

  let(:response_complete) do
    response = JSON.parse(VetsJsonSchema::EXAMPLES.fetch('SC-SHOW-RESPONSE-200_V2').to_json) # deep copy
    response['data']['attributes']['status'] = 'complete'
    instance_double(Faraday::Response, body: response)
  end

  let(:response_pending) do
    instance_double(Faraday::Response, body: VetsJsonSchema::EXAMPLES.fetch('SC-SHOW-RESPONSE-200_V2'))
  end

  let(:response_error) do
    response = JSON.parse(VetsJsonSchema::EXAMPLES.fetch('SC-SHOW-RESPONSE-200_V2').to_json) # deep copy
    response['data']['attributes']['status'] = 'error'
    instance_double(Faraday::Response, body: response)
  end

  let(:upload_response_vbms) do
    response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_upload_show_response_200.json'))
    instance_double(Faraday::Response, body: response)
  end

  let(:upload_response_processing) do
    response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_upload_show_response_200.json'))
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
        Flipper.enable :decision_review_saved_claim_sc_status_updater_job_enabled
        allow(StatsD).to receive(:increment)
      end

      context 'SavedClaim records are present and there are no evidence uploads' do
        before do
          SavedClaim::SupplementalClaim.create(guid: guid1, form: '{}')
          SavedClaim::SupplementalClaim.create(guid: guid2, form: '{}')
          SavedClaim::SupplementalClaim.create(guid: guid3, form: '{}', delete_date: DateTime.new(2024, 2, 1).utc)
          SavedClaim::HigherLevelReview.create(form: '{}')
          SavedClaim::NoticeOfDisagreement.create(form: '{}')
        end

        it 'updates SavedClaim::SupplementalClaim delete_date for completed records without a delete_date' do
          expect(service).to receive(:get_supplemental_claim).with(guid1).and_return(response_complete)
          expect(service).to receive(:get_supplemental_claim).with(guid2).and_return(response_pending)
          expect(service).not_to receive(:get_supplemental_claim).with(guid3)

          expect(service).not_to receive(:get_higher_level_review)
          expect(service).not_to receive(:get_notice_of_disagreement)

          frozen_time = DateTime.new(2024, 1, 1).utc

          Timecop.freeze(frozen_time) do
            subject.new.perform

            claim1 = SavedClaim::SupplementalClaim.find_by(guid: guid1)
            expect(claim1.delete_date).to eq frozen_time + 59.days
            expect(claim1.metadata).to include 'complete'
            expect(claim1.metadata_updated_at).to eq frozen_time

            claim2 = SavedClaim::SupplementalClaim.find_by(guid: guid2)
            expect(claim2.delete_date).to be_nil
            expect(claim2.metadata).to include 'pending'
            expect(claim2.metadata_updated_at).to eq frozen_time
          end

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_sc_status_updater.processing_records', 2).exactly(1).time
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_sc_status_updater.delete_date_update').exactly(1).time
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_sc_status_updater.status', tags: ['status:pending'])
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
          SavedClaim::SupplementalClaim.create(guid: guid1, form: '{}')
          SavedClaim::SupplementalClaim.create(guid: guid2, form: '{}')
          SavedClaim::SupplementalClaim.create(guid: guid3, form: '{}')

          appeal_submission = create(:appeal_submission, submitted_appeal_uuid: guid1)
          create(:appeal_submission_upload, appeal_submission:, lighthouse_upload_id: upload_id)

          appeal_submission2 = create(:appeal_submission, submitted_appeal_uuid: guid2)
          create(:appeal_submission_upload, appeal_submission: appeal_submission2, lighthouse_upload_id: upload_id2)

          # One upload vbms, other one still processing
          appeal_submission3 = create(:appeal_submission, submitted_appeal_uuid: guid3)
          create(:appeal_submission_upload, appeal_submission: appeal_submission3, lighthouse_upload_id: upload_id3)
          create(:appeal_submission_upload, appeal_submission: appeal_submission3, lighthouse_upload_id: upload_id4)
        end

        it 'only sets delete_date for SavedClaim::SupplementalClaim with all attachments in vbms status' do
          expect(service).to receive(:get_supplemental_claim_upload).with(uuid: upload_id)
                                                                    .and_return(upload_response_vbms)
          expect(service).to receive(:get_supplemental_claim_upload).with(uuid: upload_id2)
                                                                    .and_return(upload_response_processing)
          expect(service).to receive(:get_supplemental_claim_upload).with(uuid: upload_id3)
                                                                    .and_return(upload_response_vbms)
          expect(service).to receive(:get_supplemental_claim_upload).with(uuid: upload_id4)
                                                                    .and_return(upload_response_processing)

          expect(service).to receive(:get_supplemental_claim).with(guid1).and_return(response_complete)
          expect(service).to receive(:get_supplemental_claim).with(guid2).and_return(response_complete)
          expect(service).to receive(:get_supplemental_claim).with(guid3).and_return(response_complete)

          frozen_time = DateTime.new(2024, 1, 1).utc

          Timecop.freeze(frozen_time) do
            subject.new.perform

            claim1 = SavedClaim::SupplementalClaim.find_by(guid: guid1)
            expect(claim1.delete_date).to eq frozen_time + 59.days
            expect(claim1.metadata_updated_at).to eq frozen_time
            expect(claim1.metadata).to include 'complete'
            expect(claim1.metadata).to include 'vbms'

            claim2 = SavedClaim::SupplementalClaim.find_by(guid: guid2)
            expect(claim2.delete_date).to be_nil
            expect(claim2.metadata_updated_at).to eq frozen_time
            expect(claim2.metadata).to include 'complete'
            expect(claim2.metadata).to include 'processing'

            claim3 = SavedClaim::SupplementalClaim.find_by(guid: guid3)
            expect(claim3.delete_date).to be_nil
            expect(claim3.metadata_updated_at).to eq frozen_time

            metadata3 = JSON.parse(claim3.metadata)
            expect(metadata3['status']).to eq 'complete'
            expect(metadata3['uploads'].pluck('id', 'status'))
              .to contain_exactly([upload_id3, 'vbms'], [upload_id4, 'processing'])
          end

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_sc_status_updater.processing_records', 3).exactly(1).time
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_sc_status_updater.delete_date_update').exactly(1).time
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_sc_status_updater.status', tags: ['status:complete'])
            .exactly(2).times
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_sc_status_updater_upload.status', tags: ['status:vbms'])
            .exactly(2).times
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_sc_status_updater_upload.status', tags: ['status:processing'])
            .exactly(2).times
          expect(Rails.logger).not_to have_received(:info)
            .with('DecisionReview::SavedClaimScStatusUpdaterJob evidence status error', anything)
        end
      end

      context 'SavedClaim records are present with completed status in LH and have associated secondary forms' do
        let(:benefits_intake_service) { instance_double(BenefitsIntake::Service) }
        let!(:secondary_form1) { create(:secondary_appeal_form4142, guid: SecureRandom.uuid) }
        let!(:secondary_form2) { create(:secondary_appeal_form4142, guid: SecureRandom.uuid) }
        let!(:secondary_form3) { create(:secondary_appeal_form4142, guid: SecureRandom.uuid) }
        let!(:secondary_form_with_delete_date) do
          create(:secondary_appeal_form4142, guid: SecureRandom.uuid, delete_date: 10.days.from_now)
        end
        let!(:saved_claim1) do
          SavedClaim::SupplementalClaim.create(guid: secondary_form1.appeal_submission.submitted_appeal_uuid,
                                               form: '{}')
        end
        let!(:saved_claim2) do
          SavedClaim::SupplementalClaim.create(guid: secondary_form2.appeal_submission.submitted_appeal_uuid,
                                               form: '{}')
        end
        let!(:saved_claim3) do
          SavedClaim::SupplementalClaim.create(guid: secondary_form3.appeal_submission.submitted_appeal_uuid,
                                               form: '{}')
        end
        let!(:saved_claim4) do
          SavedClaim::SupplementalClaim
            .create(guid: secondary_form_with_delete_date.appeal_submission.submitted_appeal_uuid, form: '{}')
        end

        let(:upload_response_4142_vbms) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          instance_double(Faraday::Response, body: response)
        end

        let(:upload_response_4142_processing) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'processing'
          instance_double(Faraday::Response, body: response)
        end

        let(:upload_response_4142_error) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'error'
          response['data']['attributes']['detail'] = 'Invalid PDF'
          instance_double(Faraday::Response, body: response)
        end

        before do
          allow(DecisionReviewV1::Service).to receive(:new).and_return(service)
          allow(BenefitsIntake::Service).to receive(:new).and_return(benefits_intake_service)
          allow(service).to receive(:get_supplemental_claim).with(saved_claim1.guid).and_return(response_complete)
          allow(service).to receive(:get_supplemental_claim).with(saved_claim2.guid).and_return(response_complete)
          allow(service).to receive(:get_supplemental_claim).with(saved_claim3.guid).and_return(response_complete)
          allow(service).to receive(:get_supplemental_claim).with(saved_claim4.guid).and_return(response_complete)

          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:info)
        end

        it 'does NOT check status for 4142 records that already have a delete_date' do
          expect(benefits_intake_service).to receive(:get_status).with(uuid: secondary_form1.guid)
          expect(benefits_intake_service).to receive(:get_status).with(uuid: secondary_form2.guid)
          expect(benefits_intake_service).to receive(:get_status).with(uuid: secondary_form3.guid)
          expect(benefits_intake_service).not_to receive(:get_status)
            .with(uuid: secondary_form_with_delete_date.guid)
          subject.new.perform
        end

        context 'updating 4142 information' do
          let(:frozen_time) { DateTime.new(2024, 1, 1).utc }

          before do
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form1.guid).and_return(upload_response_4142_vbms)
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form2.guid).and_return(upload_response_4142_processing)
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form3.guid).and_return(upload_response_4142_error)
          end

          it 'updates the status and sets delete_date if appropriate' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end
            expect(secondary_form1.reload.status).to include('vbms')
            expect(secondary_form1.reload.status_updated_at).to eq frozen_time
            expect(secondary_form1.reload.delete_date).to eq frozen_time + 59.days

            expect(secondary_form2.reload.status).to include('processing')
            expect(secondary_form2.reload.status_updated_at).to eq frozen_time
            expect(secondary_form2.reload.delete_date).to be_nil

            expect(secondary_form3.reload.status).to include('error')
            expect(secondary_form3.reload.status_updated_at).to eq frozen_time
            expect(secondary_form3.reload.delete_date).to be_nil
          end

          it 'logs ands increments metrics for updates to the 4142 status' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.saved_claim_sc_status_updater_secondary_form.delete_date_update')
              .exactly(1).time
            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.saved_claim_sc_status_updater_secondary_form.status', tags: ['status:vbms'])
              .exactly(1).time
            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.saved_claim_sc_status_updater_secondary_form.status',
                    tags: ['status:processing'])
              .exactly(1).time

            expect(Rails.logger).to have_received(:info)
              .with('DecisionReview::SavedClaimScStatusUpdaterJob secondary form status error', anything)
            expect(StatsD).to have_received(:increment)
              .with('silent_failure', tags: ['service:supplemental-claims-4142',
                                             'function: PDF submission to Lighthouse'])
              .exactly(1).time
          end

          context 'when the 4142 status is unchanged' do
            let(:previous_status) do
              {
                'status' => 'processing'
              }
            end

            before do
              secondary_form2.update!(status: previous_status.to_json, status_updated_at: frozen_time - 3.days)
            end

            it 'does not log or increment metrics for a status change' do
              Timecop.freeze(frozen_time) do
                subject.new.perform
              end

              expect(secondary_form2.reload.status_updated_at).to eq frozen_time
              expect(StatsD).not_to have_received(:increment)
                .with('worker.decision_review.saved_claim_sc_status_updater_secondary_form.status',
                      tags: ['status:processing'])
            end
          end

          context 'when at least one secondary form is not in vbms status' do
            it 'does not set the delete_date for the related SavedCalim::SupplementlClaim' do
              Timecop.freeze(frozen_time) do
                subject.new.perform
              end

              expect(saved_claim1.reload.delete_date).to eq frozen_time + 59.days
              expect(saved_claim2.delete_date).to be_nil
            end
          end
        end

        context 'with 4142 flag disabled' do
          before do
            Flipper.disable :decision_review_track_4142_submissions
          end

          it 'does not query SecondaryAppealForm records' do
            expect(SecondaryAppealForm).not_to receive(:where)

            subject.new.perform
          end
        end
      end

      context 'SavedClaim record with previous metadata' do
        before do
          allow(Rails.logger).to receive(:info)
        end

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

        it 'does not increment metrics for unchanged form status' do
          SavedClaim::SupplementalClaim.create(guid: guid1, form: '{}', metadata: '{"status":"error","uploads":[]}')
          SavedClaim::SupplementalClaim.create(guid: guid2, form: '{}', metadata: '{"status":"submitted","uploads":[]}')

          expect(service).to receive(:get_supplemental_claim).with(guid1).and_return(response_error)
          expect(service).to receive(:get_supplemental_claim).with(guid2).and_return(response_error)

          subject.new.perform

          claim1 = SavedClaim::SupplementalClaim.find_by(guid: guid1)
          expect(claim1.delete_date).to be_nil
          expect(claim1.metadata).to include 'error'

          claim2 = SavedClaim::SupplementalClaim.find_by(guid: guid2)
          expect(claim2.delete_date).to be_nil
          expect(claim2.metadata).to include 'error'

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_sc_status_updater.status', tags: ['status:error'])
            .exactly(1).time

          expect(Rails.logger).not_to have_received(:info)
            .with('DecisionReview::SavedClaimScStatusUpdaterJob form status error', guid: guid1)
          expect(Rails.logger).to have_received(:info)
            .with('DecisionReview::SavedClaimScStatusUpdaterJob form status error', guid: guid2)
        end

        it 'does not increment metrics for unchanged evidence status' do
          SavedClaim::SupplementalClaim.create(guid: guid1, form: '{}', metadata: metadata1.to_json)
          appeal_submission = create(:appeal_submission, submitted_appeal_uuid: guid1)
          create(:appeal_submission_upload, appeal_submission:, lighthouse_upload_id: upload_id)

          SavedClaim::SupplementalClaim.create(guid: guid2, form: '{}', metadata: metadata2.to_json)
          appeal_submission2 = create(:appeal_submission, submitted_appeal_uuid: guid2)
          create(:appeal_submission_upload, appeal_submission: appeal_submission2, lighthouse_upload_id: upload_id2)
          create(:appeal_submission_upload, appeal_submission: appeal_submission2, lighthouse_upload_id: upload_id3)

          expect(service).to receive(:get_supplemental_claim).with(guid1).and_return(response_pending)
          expect(service).to receive(:get_supplemental_claim).with(guid2).and_return(response_error)
          expect(service).to receive(:get_supplemental_claim_upload).with(uuid: upload_id)
                                                                    .and_return(upload_response_error)
          expect(service).to receive(:get_supplemental_claim_upload).with(uuid: upload_id2)
                                                                    .and_return(upload_response_error)
          expect(service).to receive(:get_supplemental_claim_upload).with(uuid: upload_id3)
                                                                    .and_return(upload_response_processing)

          subject.new.perform

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_sc_status_updater_upload.status', tags: ['status:error'])
            .exactly(1).times
          expect(StatsD).not_to have_received(:increment)
            .with('worker.decision_review.saved_claim_sc_status_updater_upload.status', tags: ['status:processing'])

          expect(Rails.logger).not_to have_received(:info)
            .with('DecisionReview::SavedClaimScStatusUpdaterJob evidence status error',
                  guid: anything, lighthouse_upload_id: upload_id, detail: anything)
          expect(Rails.logger).to have_received(:info)
            .with('DecisionReview::SavedClaimScStatusUpdaterJob evidence status error',
                  guid: guid2, lighthouse_upload_id: upload_id2, detail: 'Invalid PDF')
        end
      end

      context 'an error occurs while processing form, attachments, or secondary form' do
        before do
          SavedClaim::SupplementalClaim.create(guid: SecureRandom.uuid, form: '{}')
          SavedClaim::SupplementalClaim.create(guid: SecureRandom.uuid, form: '{}')
        end

        it 'handles request errors and increments the statsd metric' do
          allow(service).to receive(:get_supplemental_claim).and_raise(DecisionReviewV1::ServiceException)

          subject.new.perform

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_sc_status_updater.error').exactly(2).times
        end
      end
    end

    context 'with flag disabled' do
      before do
        Flipper.disable :decision_review_saved_claim_sc_status_updater_job_enabled
      end

      it 'does not query SavedClaim::HigherLevelReview records' do
        expect(SavedClaim::HigherLevelReview).not_to receive(:where)

        subject.new.perform
      end
    end
  end
end
