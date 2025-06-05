# frozen_string_literal: true

require './modules/decision_reviews/spec/support/engine_shared_examples_for_status_updater_jobs'

RSpec.describe DecisionReviews::ScStatusUpdaterJob, type: :job do
  subject { described_class }

  include_context 'engine status updater job context', SavedClaim::SupplementalClaim

  describe 'perform' do
    context 'with flag enabled', :aggregate_failures do
      before do
        allow(Flipper).to receive(:enabled?).with(:decision_review_saved_claim_sc_status_updater_job_enabled)
                                            .and_return(true)
        allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_call_original
        allow(Flipper).to receive(:enabled?).with(:decision_review_track_4142_submissions).and_return(true)
      end

      include_examples 'engine status updater job with base forms', SavedClaim::SupplementalClaim
      include_examples 'engine status updater job when forms include evidence', SavedClaim::SupplementalClaim

      context 'SavedClaim records are present with completed status in LH and have associated secondary forms' do
        let(:benefits_intake_service) { instance_double(BenefitsIntake::Service) }
        let!(:secondary_form1) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:secondary_form2) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:secondary_form3) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:secondary_form_with_delete_date) do
          create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid, delete_date: 10.days.from_now)
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
          allow(DecisionReviews::V1::Service).to receive(:new).and_return(service)
          allow(BenefitsIntake::Service).to receive(:new).and_return(benefits_intake_service)
          allow(service).to receive(:get_supplemental_claim).with(saved_claim1.guid).and_return(response_complete)
          allow(service).to receive(:get_supplemental_claim).with(saved_claim2.guid).and_return(response_complete)
          allow(service).to receive(:get_supplemental_claim).with(saved_claim3.guid).and_return(response_complete)
          allow(service).to receive(:get_supplemental_claim).with(saved_claim4.guid).and_return(response_complete)

          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:info)
        end

        after do
          benefits_intake_service { nil }
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
              .with('DecisionReviews::SavedClaimScStatusUpdaterJob secondary form status error', anything)
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
            allow(Flipper).to receive(:enabled?).with(:decision_review_track_4142_submissions).and_return(false)
          end

          it 'does not query SecondaryAppealForm records' do
            expect(SecondaryAppealForm).not_to receive(:where)

            subject.new.perform
          end
        end
      end
    end

    context 'with flag disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:decision_review_saved_claim_sc_status_updater_job_enabled)
                                            .and_return(false)
        allow(Flipper).to receive(:enabled?).with(:decision_review_track_4142_submissions).and_return(false)
      end

      it 'does not query SavedClaim::SupplementalClaim records' do
        expect(SavedClaim::SupplementalClaim).not_to receive(:where)

        subject.new.perform
      end
    end
  end
end
