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

      context 'final_status polling and completion logic' do
        let(:benefits_intake_service) { instance_double(BenefitsIntake::Service) }
        let(:frozen_time) { DateTime.new(2024, 1, 1).utc }

        let!(:form_vbms_final) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:form_error_recoverable) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:form_error_permanent) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:form_processing_active) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }

        let!(:saved_claim_vbms) do
          SavedClaim::SupplementalClaim.create(
            guid: form_vbms_final.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end
        let!(:saved_claim_recoverable) do
          SavedClaim::SupplementalClaim.create(
            guid: form_error_recoverable.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end
        let!(:saved_claim_permanent) do
          SavedClaim::SupplementalClaim.create(
            guid: form_error_permanent.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end
        let!(:saved_claim_processing) do
          SavedClaim::SupplementalClaim.create(
            guid: form_processing_active.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end

        let(:response_vbms_final) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'vbms'
          response['data']['attributes']['final_status'] = true
          response['data']['attributes']['detail'] = ''
          instance_double(Faraday::Response, body: response)
        end

        let(:response_error_recoverable) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'error'
          response['data']['attributes']['final_status'] = false
          response['data']['attributes']['code'] = 'DOC105'
          response['data']['attributes']['detail'] = 'Service temporarily unavailable. Please try again later.'
          instance_double(Faraday::Response, body: response)
        end

        let(:response_error_permanent) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'error'
          response['data']['attributes']['final_status'] = true
          response['data']['attributes']['code'] = 'DOC108'
          response['data']['attributes']['detail'] = 'Maximum page size exceeded. Limit is 78 in x 101 in.'
          instance_double(Faraday::Response, body: response)
        end

        let(:response_processing_active) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'processing'
          response['data']['attributes']['final_status'] = false
          response['data']['attributes']['detail'] = 'Form is being processed'
          instance_double(Faraday::Response, body: response)
        end

        before do
          allow(DecisionReviews::V1::Service).to receive(:new).and_return(service)
          allow(BenefitsIntake::Service).to receive(:new).and_return(benefits_intake_service)

          allow(service).to receive(:get_supplemental_claim).with(saved_claim_vbms.guid).and_return(response_complete)
          # rubocop:disable Layout/LineLength
          allow(service).to receive(:get_supplemental_claim).with(saved_claim_recoverable.guid).and_return(response_complete)
          allow(service).to receive(:get_supplemental_claim).with(saved_claim_permanent.guid).and_return(response_complete)
          allow(service).to receive(:get_supplemental_claim).with(saved_claim_processing.guid).and_return(response_complete)
          # rubocop:enable Layout/LineLength

          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: form_vbms_final.guid).and_return(response_vbms_final)
          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: form_error_recoverable.guid).and_return(response_error_recoverable)
          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: form_error_permanent.guid).and_return(response_error_permanent)
          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: form_processing_active.guid).and_return(response_processing_active)

          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:info)
        end

        after do
          benefits_intake_service { nil }
        end

        context 'polling behavior' do
          it 'processes all forms and makes API calls for each' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(benefits_intake_service).to have_received(:get_status).with(uuid: form_vbms_final.guid)
            expect(benefits_intake_service).to have_received(:get_status).with(uuid: form_error_recoverable.guid)
            expect(benefits_intake_service).to have_received(:get_status).with(uuid: form_error_permanent.guid)
            expect(benefits_intake_service).to have_received(:get_status).with(uuid: form_processing_active.guid)
          end

          it 'continues polling for recoverable errors (active mitigation)' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            # Verify API call was made for recoverable error
            expect(benefits_intake_service).to have_received(:get_status).with(uuid: form_error_recoverable.guid)

            # Verify status was updated with fresh API data including final_status: false
            form_error_recoverable.reload
            parsed_status = JSON.parse(form_error_recoverable.status)
            expect(parsed_status['status']).to eq('error')
            expect(parsed_status['final_status']).to be(false)
            expect(parsed_status['detail']).to eq('Service temporarily unavailable. Please try again later.')
          end

          it 'continues polling for active processing forms' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            # Verify API call was made for processing form
            expect(benefits_intake_service).to have_received(:get_status).with(uuid: form_processing_active.guid)

            # Verify status was updated with final_status: false
            form_processing_active.reload
            parsed_status = JSON.parse(form_processing_active.status)
            expect(parsed_status['status']).to eq('processing')
            expect(parsed_status['final_status']).to be(false)
          end

          it 'processes all forms and updates their records' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            # Verify all forms got their timestamps updated
            expect(form_vbms_final.reload.status_updated_at).to eq(frozen_time)
            expect(form_error_recoverable.reload.status_updated_at).to eq(frozen_time)
            expect(form_error_permanent.reload.status_updated_at).to eq(frozen_time)
            expect(form_processing_active.reload.status_updated_at).to eq(frozen_time)
          end
        end

        context 'final_status data storage and retrieval' do
          before do
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: form_vbms_final.guid).and_return(response_vbms_final)
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: form_error_permanent.guid).and_return(response_error_permanent)
          end

          it 'stores complete final_status data from API responses' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            form_vbms_final.reload
            vbms_status = JSON.parse(form_vbms_final.status)
            expect(vbms_status['status']).to eq('vbms')
            expect(vbms_status['final_status']).to be(true)
            expect(vbms_status['detail']).to eq('')
            expect(vbms_status['updated_at']).to eq('2024-10-25T17:39:58.166Z')

            form_error_permanent.reload
            error_status = JSON.parse(form_error_permanent.status)
            expect(error_status['status']).to eq('error')
            expect(error_status['final_status']).to be(true)
            expect(error_status['detail']).to eq('Maximum page size exceeded. Limit is 78 in x 101 in.')
          end

          it 'updates status_updated_at for all processed forms' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(form_vbms_final.reload.status_updated_at).to eq(frozen_time)
            expect(form_error_permanent.reload.status_updated_at).to eq(frozen_time)
          end
        end

        context 'delete_date setting requires both success AND final_status' do
          before do
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: form_vbms_final.guid).and_return(response_vbms_final)
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: form_error_permanent.guid).and_return(response_error_permanent)
          end

          it 'sets delete_date only when status=vbms AND final_status=true' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            # Successful AND final form should get delete_date
            form_vbms_final.reload
            expect(form_vbms_final.delete_date).to eq(frozen_time + 59.days)
          end

          it 'increments delete_date metrics only for qualifying forms' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            # Should only increment once for the successful+final form
            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.saved_claim_sc_status_updater_secondary_form.delete_date_update')
              .exactly(1).time
          end
        end

        context 'record completion requires ALL secondary forms to be successful AND final' do
          let!(:multi_form_submission) { create(:appeal_submission) }
          let!(:multi_form_one) do
            create(:secondary_appeal_form4142_module,
                   guid: SecureRandom.uuid,
                   appeal_submission: multi_form_submission)
          end
          let!(:multi_form_two) do
            create(:secondary_appeal_form4142_module,
                   guid: SecureRandom.uuid,
                   appeal_submission: multi_form_submission)
          end
          let!(:saved_claim_multi) do
            SavedClaim::SupplementalClaim.create(
              guid: multi_form_submission.submitted_appeal_uuid,
              form: '{}'
            )
          end

          before do
            allow(service).to receive(:get_supplemental_claim)
              .with(saved_claim_multi.guid).and_return(response_complete)
          end

          context 'when all secondary forms are successful AND final' do
            before do
              allow(benefits_intake_service).to receive(:get_status)
                .with(uuid: multi_form_one.guid).and_return(response_vbms_final)
              allow(benefits_intake_service).to receive(:get_status)
                .with(uuid: multi_form_two.guid).and_return(response_vbms_final)
            end

            it 'marks entire record as complete and sets main delete_date' do
              Timecop.freeze(frozen_time) do
                subject.new.perform
              end

              # Main record should get delete_date when ALL secondary forms are vbms+final
              saved_claim_multi.reload
              expect(saved_claim_multi.delete_date).to eq(frozen_time + 59.days)
            end
          end

          context 'when one form is successful but another has permanent error' do
            before do
              allow(benefits_intake_service).to receive(:get_status)
                .with(uuid: multi_form_one.guid).and_return(response_vbms_final)
              allow(benefits_intake_service).to receive(:get_status)
                .with(uuid: multi_form_two.guid).and_return(response_error_permanent)
            end

            it 'does not mark record as complete due to permanent error' do
              Timecop.freeze(frozen_time) do
                subject.new.perform
              end

              saved_claim_multi.reload
              expect(saved_claim_multi.delete_date).to be_nil
            end
          end

          context 'when one form has recoverable error (active mitigation scenario)' do
            before do
              allow(benefits_intake_service).to receive(:get_status)
                .with(uuid: multi_form_one.guid).and_return(response_vbms_final)
              allow(benefits_intake_service).to receive(:get_status)
                .with(uuid: multi_form_two.guid).and_return(response_error_recoverable)
            end

            it 'does not mark record as complete and continues mitigation' do
              Timecop.freeze(frozen_time) do
                subject.new.perform
              end

              # Main record should NOT get delete_date when secondary form might still recover
              saved_claim_multi.reload
              expect(saved_claim_multi.delete_date).to be_nil

              # Recoverable form should continue being polled next time
              expect(benefits_intake_service).to have_received(:get_status).with(uuid: multi_form_two.guid)
            end
          end
        end

        context 'metrics and logging behavior with final_status' do
          it 'logs errors appropriately for both recoverable and permanent errors' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(Rails.logger).to have_received(:info)
              .with('DecisionReviews::SavedClaimScStatusUpdaterJob secondary form status error',
                    hash_including(guid: form_error_permanent.guid))
          end

          it 'increments status metrics for all processed forms' do
            allow(StatsD).to receive(:increment)

            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.saved_claim_sc_status_updater_secondary_form.status',
                    tags: ['status:error']).twice # recoverable + permanent error
            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.saved_claim_sc_status_updater_secondary_form.status',
                    tags: ['status:vbms']).once
            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.saved_claim_sc_status_updater_secondary_form.status',
                    tags: ['status:processing']).once
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
