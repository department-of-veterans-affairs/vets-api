# frozen_string_literal: true

require './modules/decision_reviews/spec/support/engine_shared_examples_for_status_updater_jobs'

RSpec.describe DecisionReviews::ScStatusUpdaterJob, type: :job do
  subject { described_class }

  include_context 'engine status updater job context', SavedClaim::SupplementalClaim

  # CORE FUNCTIONALITY TESTS (PERMANENT - Will remain after all flags removed)
  describe 'perform' do
    context 'when flag is enabled', :aggregate_failures do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_saved_claim_sc_status_updater_job_enabled).and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_final_status_polling).and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:saved_claim_pdf_overflow_tracking).and_call_original
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_track_4142_submissions).and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_stuck_records_monitoring).and_return(false)
      end

      include_examples 'engine status updater job with base forms', SavedClaim::SupplementalClaim
      include_examples 'engine status updater job when forms include evidence', SavedClaim::SupplementalClaim
    end

    context 'when flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_saved_claim_sc_status_updater_job_enabled).and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_track_4142_submissions).and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_stuck_records_monitoring).and_return(false)
      end

      it 'does not query SavedClaim::SupplementalClaim records' do
        expect(SavedClaim::SupplementalClaim).not_to receive(:where)
        subject.new.perform
      end
    end
  end

  # ORIGINAL COMPLEX SCENARIOS (TEMPORARY - Legacy test preserved for validation)
  describe 'original complex scenarios', :legacy_validation do
    context 'SavedClaim records are present with completed status in LH and have associated secondary forms' do
      let(:benefits_intake_service) { instance_double(BenefitsIntake::Service) }
      let!(:secondary_form1) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
      let!(:secondary_form2) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
      let!(:secondary_form3) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
      let!(:secondary_form_with_delete_date) do
        create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid, delete_date: 10.days.from_now)
      end
      let!(:saved_claim1) do
        SavedClaim::SupplementalClaim.create(guid: secondary_form1.appeal_submission.submitted_appeal_uuid, form: '{}')
      end
      let!(:saved_claim2) do
        SavedClaim::SupplementalClaim.create(guid: secondary_form2.appeal_submission.submitted_appeal_uuid, form: '{}')
      end
      let!(:saved_claim3) do
        SavedClaim::SupplementalClaim.create(guid: secondary_form3.appeal_submission.submitted_appeal_uuid, form: '{}')
      end
      let!(:saved_claim4) do
        SavedClaim::SupplementalClaim.create(
          guid: secondary_form_with_delete_date.appeal_submission.submitted_appeal_uuid,
          form: '{}'
        )
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
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_saved_claim_sc_status_updater_job_enabled).and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_final_status_polling).and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:saved_claim_pdf_overflow_tracking).and_call_original
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_track_4142_submissions).and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_stuck_records_monitoring).and_return(false)

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
        allow(benefits_intake_service).to receive(:get_status)

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

        it 'logs and increments metrics for updates to the 4142 status' do
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
    end
  end

  # ENHANCED POLLING BEHAVIOR (PERMANENT - New feature, becomes default after flag removal)
  describe 'enhanced secondary form processing' do
    context 'when enhanced polling is enabled', :aggregate_failures do
      let(:benefits_intake_service) { instance_double(BenefitsIntake::Service) }
      let(:frozen_time) { DateTime.new(2024, 1, 1).utc }

      before do
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_saved_claim_sc_status_updater_job_enabled).and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_track_4142_submissions).and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_final_status_polling).and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:saved_claim_pdf_overflow_tracking).and_call_original
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_stuck_records_monitoring).and_return(false)
        allow(DecisionReviews::V1::Service).to receive(:new).and_return(service)
        allow(BenefitsIntake::Service).to receive(:new).and_return(benefits_intake_service)
        allow(StatsD).to receive(:increment)
        allow(Rails.logger).to receive(:info)
      end

      after do
        benefits_intake_service { nil }
      end

      context 'when forms have final_status = true' do
        let!(:secondary_form) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:saved_claim) do
          SavedClaim::SupplementalClaim.create(
            guid: secondary_form.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end

        let(:stored_final_status) do
          {
            'status' => 'vbms',
            'final_status' => true,
            'detail' => 'Completed',
            'updated_at' => '2024-01-01T10:00:00.000Z'
          }
        end

        before do
          secondary_form.update!(status: stored_final_status.to_json)
          allow(service).to receive(:get_supplemental_claim)
            .with(saved_claim.guid).and_return(response_complete)
          allow(benefits_intake_service).to receive(:get_status)
        end

        it 'does NOT make API call and does NOT update timestamps for forms with final status' do
          original_status_updated_at = secondary_form.status_updated_at
          original_delete_date = secondary_form.delete_date

          Timecop.freeze(frozen_time) do
            subject.new.perform
          end

          expect(benefits_intake_service).not_to have_received(:get_status)
            .with(uuid: secondary_form.guid)

          expect(secondary_form.reload.status_updated_at).to eq(original_status_updated_at)
          expect(secondary_form.reload.delete_date).to eq(original_delete_date)
        end

        it 'marks record as complete when using stored final status' do
          Timecop.freeze(frozen_time) do
            subject.new.perform
          end

          saved_claim.reload
          expect(saved_claim.delete_date).to eq(frozen_time + 59.days)
        end
      end

      context 'when forms have final_status = false' do
        let!(:secondary_form) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:saved_claim) do
          SavedClaim::SupplementalClaim.create(
            guid: secondary_form.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end

        let(:stored_processing_status) do
          {
            'status' => 'processing',
            'final_status' => false,
            'detail' => 'Still processing',
            'updated_at' => '2024-01-01T10:00:00.000Z'
          }
        end

        let(:response_vbms_final) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'vbms'
          response['data']['attributes']['final_status'] = true
          instance_double(Faraday::Response, body: response)
        end

        before do
          secondary_form.update!(status: stored_processing_status.to_json)
          allow(service).to receive(:get_supplemental_claim)
            .with(saved_claim.guid).and_return(response_complete)
          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: secondary_form.guid).and_return(response_vbms_final)
        end

        it 'makes API call to get fresh status' do
          Timecop.freeze(frozen_time) do
            subject.new.perform
          end

          expect(benefits_intake_service).to have_received(:get_status)
            .with(uuid: secondary_form.guid)

          parsed_status = JSON.parse(secondary_form.reload.status)
          expect(parsed_status['status']).to eq('vbms')
          expect(parsed_status['final_status']).to be(true)
        end
      end

      context 'when forms have nil status' do
        let!(:secondary_form_nil_status) do
          create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid, status: nil)
        end
        let!(:saved_claim_nil) do
          SavedClaim::SupplementalClaim.create(
            guid: secondary_form_nil_status.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end

        let(:response_processing) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'processing'
          response['data']['attributes']['final_status'] = false
          instance_double(Faraday::Response, body: response)
        end

        before do
          allow(service).to receive(:get_supplemental_claim)
            .with(saved_claim_nil.guid).and_return(response_complete)
          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: secondary_form_nil_status.guid).and_return(response_processing)
        end

        it 'makes API call for forms with nil status (treats as non-final)' do
          Timecop.freeze(frozen_time) do
            subject.new.perform
          end

          expect(benefits_intake_service).to have_received(:get_status)
            .with(uuid: secondary_form_nil_status.guid)
        end

        it 'updates status from nil to API response' do
          Timecop.freeze(frozen_time) do
            subject.new.perform
          end

          secondary_form_nil_status.reload
          parsed_status = JSON.parse(secondary_form_nil_status.status)
          expect(parsed_status['status']).to eq('processing')
          expect(parsed_status['final_status']).to be(false)
          expect(secondary_form_nil_status.status_updated_at).to eq(frozen_time)
        end

        it 'does not set delete_date for forms transitioning from nil to processing' do
          Timecop.freeze(frozen_time) do
            subject.new.perform
          end

          expect(secondary_form_nil_status.reload.delete_date).to be_nil
        end
      end

      context 'when forms have no stored final_status (legacy data)' do
        let!(:secondary_form) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:saved_claim) do
          SavedClaim::SupplementalClaim.create(
            guid: secondary_form.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end

        let(:legacy_stored_status) do
          {
            'status' => 'processing',
            'detail' => 'Still processing'
            # NOTE: no final_status field
          }
        end

        let(:response_vbms_final) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'vbms'
          response['data']['attributes']['final_status'] = true
          instance_double(Faraday::Response, body: response)
        end

        before do
          secondary_form.update!(status: legacy_stored_status.to_json)
          allow(service).to receive(:get_supplemental_claim)
            .with(saved_claim.guid).and_return(response_complete)
          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: secondary_form.guid).and_return(response_vbms_final)
        end

        it 'makes API call to get status with final_status' do
          Timecop.freeze(frozen_time) do
            subject.new.perform
          end

          expect(benefits_intake_service).to have_received(:get_status)
            .with(uuid: secondary_form.guid)

          parsed_status = JSON.parse(secondary_form.reload.status)
          expect(parsed_status['final_status']).to be(true)
        end
      end

      context 'status processing scenarios' do
        let!(:secondary_form) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:saved_claim) do
          SavedClaim::SupplementalClaim.create(
            guid: secondary_form.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end

        before do
          allow(service).to receive(:get_supplemental_claim)
            .with(saved_claim.guid).and_return(response_complete)
        end

        context 'when API returns vbms with final_status true' do
          let(:response_vbms_final) do
            response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
            response['data']['attributes']['status'] = 'vbms'
            response['data']['attributes']['final_status'] = true
            response['data']['attributes']['detail'] = ''
            instance_double(Faraday::Response, body: response)
          end

          before do
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form.guid).and_return(response_vbms_final)
          end

          it 'sets delete_date and stores final_status' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(secondary_form.reload.delete_date).to eq(frozen_time + 59.days)
            parsed_status = JSON.parse(secondary_form.reload.status)
            expect(parsed_status['final_status']).to be(true)
          end
        end

        context 'when API returns processing with final_status false' do
          let(:response_processing_not_final) do
            response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
            response['data']['attributes']['status'] = 'processing'
            response['data']['attributes']['final_status'] = false
            response['data']['attributes']['detail'] = 'Form is being processed'
            instance_double(Faraday::Response, body: response)
          end

          before do
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form.guid).and_return(response_processing_not_final)
          end

          it 'does not set delete_date' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(secondary_form.reload.delete_date).to be_nil
            parsed_status = JSON.parse(secondary_form.reload.status)
            expect(parsed_status['final_status']).to be(false)
          end
        end

        context 'when API returns error with final_status true' do
          let(:response_error_final) do
            response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
            response['data']['attributes']['status'] = 'error'
            response['data']['attributes']['final_status'] = false
            response['data']['attributes']['detail'] = 'Invalid PDF'
            instance_double(Faraday::Response, body: response)
          end

          before do
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form.guid).and_return(response_error_final)
          end

          it 'does not set delete_date when final_status is false' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(secondary_form.reload.delete_date).to be_nil
            parsed_status = JSON.parse(secondary_form.reload.status)

            expect(parsed_status['final_status']).to be(false)
          end
        end

        context 'when API returns error with no final_status field (nil)' do
          let(:response_error_no_final_status) do
            response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
            response['data']['attributes']['status'] = 'error'
            response['data']['attributes']['detail'] = 'Document processing failed'
            response['data']['attributes']['final_status'] = nil
            instance_double(Faraday::Response, body: response)
          end

          before do
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form.guid).and_return(response_error_no_final_status)
          end

          it 'treats nil final_status as non-final and continues polling' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(secondary_form.reload.delete_date).to be_nil

            parsed_status = JSON.parse(secondary_form.reload.status)
            expect(parsed_status['status']).to eq('error')
            expect(parsed_status['final_status']).to be_nil

            expect(benefits_intake_service).to have_received(:get_status).with(uuid: secondary_form.guid)
          end

          it 'continues polling on subsequent runs since final_status is nil (not true)' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            parsed_status = JSON.parse(secondary_form.reload.status)
            expect(parsed_status['final_status']).to be_nil

            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form.guid).and_return(response_error_no_final_status)

            Timecop.freeze(frozen_time + 1.hour) do
              subject.new.perform
            end

            expect(benefits_intake_service).to have_received(:get_status).with(uuid: secondary_form.guid).twice
          end

          it 'handles nil final_status correctly in should_continue_polling?' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            stored_status = JSON.parse(secondary_form.reload.status)
            expect(stored_status['final_status']).to be_nil

            # The logic should treat nil as "continue polling"
            # This is implicitly tested by the fact that the API was called above,
            # but we can also verify by checking that no delete_date was set
            expect(secondary_form.reload.delete_date).to be_nil
          end
        end
      end

      context 'multi-form completion logic' do
        let!(:multi_form_submission) { create(:appeal_submission) }
        let!(:form_one) do
          create(:secondary_appeal_form4142_module,
                 guid: SecureRandom.uuid,
                 appeal_submission: multi_form_submission)
        end
        let!(:form_two) do
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
          let(:response_vbms_final) do
            response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
            response['data']['attributes']['status'] = 'vbms'
            response['data']['attributes']['final_status'] = true
            instance_double(Faraday::Response, body: response)
          end

          before do
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: form_one.guid).and_return(response_vbms_final)
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: form_two.guid).and_return(response_vbms_final)
          end

          it 'marks entire record as complete and sets main delete_date' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            saved_claim_multi.reload
            expect(saved_claim_multi.delete_date).to eq(frozen_time + 59.days)
          end
        end

        context 'when one form has recoverable error (we should continue polling for status updates)' do
          let(:response_vbms_final) do
            response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
            response['data']['attributes']['status'] = 'vbms'
            response['data']['attributes']['final_status'] = true
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

          before do
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: form_one.guid).and_return(response_vbms_final)
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: form_two.guid).and_return(response_error_recoverable)
          end

          it 'does not mark record as complete and continues polling' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            saved_claim_multi.reload
            expect(saved_claim_multi.delete_date).to be_nil
            expect(benefits_intake_service).to have_received(:get_status).with(uuid: form_two.guid)
          end
        end
      end

      context 'forms with existing delete_date' do
        let!(:secondary_form_with_delete_date) do
          create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid, delete_date: 10.days.from_now)
        end
        let!(:secondary_form_without_delete_date) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:saved_claim) do
          SavedClaim::SupplementalClaim.create(
            guid: secondary_form_without_delete_date.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end

        before do
          allow(service).to receive(:get_supplemental_claim)
            .with(saved_claim.guid).and_return(response_complete)
        end

        it 'does NOT check status for forms that already have a delete_date' do
          allow(benefits_intake_service).to receive(:get_status)

          expect(benefits_intake_service).to receive(:get_status).with(uuid: secondary_form_without_delete_date.guid)
          expect(benefits_intake_service).not_to receive(:get_status)
            .with(uuid: secondary_form_with_delete_date.guid)

          subject.new.perform
        end
      end

      context 'metrics and logging behavior' do
        let!(:secondary_form) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:saved_claim) do
          SavedClaim::SupplementalClaim.create(
            guid: secondary_form.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end

        before do
          allow(service).to receive(:get_supplemental_claim)
            .with(saved_claim.guid).and_return(response_complete)
        end

        it 'logs and increments metrics for updates to the status' do
          response_vbms = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response_vbms['data']['attributes']['status'] = 'vbms'
          response_vbms['data']['attributes']['final_status'] = true
          vbms_response = instance_double(Faraday::Response, body: response_vbms)

          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: secondary_form.guid).and_return(vbms_response)

          Timecop.freeze(frozen_time) do
            subject.new.perform
          end

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_sc_status_updater_secondary_form.delete_date_update')
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.saved_claim_sc_status_updater_secondary_form.status', tags: ['status:vbms'])
        end

        it 'logs errors for error statuses' do
          response_error = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response_error['data']['attributes']['status'] = 'error'
          response_error['data']['attributes']['final_status'] = true
          response_error['data']['attributes']['detail'] = 'Invalid PDF'
          error_response = instance_double(Faraday::Response, body: response_error)

          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: secondary_form.guid).and_return(error_response)

          Timecop.freeze(frozen_time) do
            subject.new.perform
          end

          expect(Rails.logger).to have_received(:info)
            .with('DecisionReviews::SavedClaimScStatusUpdaterJob secondary form status error', anything)
        end
      end

      # NEW TESTS FOR 15-DAY MONITORING
      context 'temporary error monitoring' do
        let!(:secondary_form) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:saved_claim) do
          SavedClaim::SupplementalClaim.create(
            guid: secondary_form.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end

        let(:response_processing) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'processing'
          response['data']['attributes']['final_status'] = false
          instance_double(Faraday::Response, body: response)
        end

        before do
          allow(service).to receive(:get_supplemental_claim)
            .with(saved_claim.guid).and_return(response_complete)
          allow(Rails.logger).to receive(:info)
        end

        context 'when form has temporary error (final_status: false) for exactly 15 days' do
          let(:temp_error_status) do
            {
              'status' => 'error',
              'final_status' => false,
              'detail' => 'Temporary processing error'
            }
          end

          before do
            secondary_form.update!(
              status: temp_error_status.to_json,
              status_updated_at: frozen_time - 15.days
            )

            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form.guid).and_return(response_processing)
          end

          it 'does not log warning at exactly 15 days' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(Rails.logger).not_to have_received(:info).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob secondary form stuck in temporary error state',
              anything
            )
          end

          it 'continues polling the form' do
            processing_response = instance_double(Faraday::Response, body: {
                                                    'data' => {
                                                      'attributes' => {
                                                        'status' => 'processing',
                                                        'final_status' => false,
                                                        'detail' => 'Still processing',
                                                        'updated_at' => Time.current.iso8601
                                                      }
                                                    }
                                                  })

            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form.guid).and_return(processing_response)

            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(benefits_intake_service).to have_received(:get_status).with(uuid: secondary_form.guid)
          end
        end

        context 'when form has temporary error (final_status: false) for more than 15 days' do
          let(:temp_error_status) do
            {
              'status' => 'error',
              'final_status' => false,
              'detail' => 'Temporary processing error',
              'code' => 'DOC105'
            }
          end

          let(:days_in_error) { 17.5 }
          let(:error_timestamp) { frozen_time - days_in_error.days }

          before do
            secondary_form.update!(
              status: temp_error_status.to_json,
              status_updated_at: error_timestamp,
              created_at: error_timestamp
            )

            # Reload to ensure we have the actual database value
            secondary_form.reload

            # Create response that keeps the form in error state with final_status: false
            response_error_non_final = JSON.parse(
              File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json')
            )
            response_error_non_final['data']['attributes']['status'] = 'error'
            response_error_non_final['data']['attributes']['final_status'] = false
            response_error_non_final['data']['attributes']['detail'] = 'Temporary processing error'
            error_non_final_response = instance_double(Faraday::Response, body: response_error_non_final)

            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form.guid).and_return(error_non_final_response)

            allow(Rails.logger).to receive(:info).and_call_original
          end

          it 'logs warning with correct attributes' do
            expect(Rails.logger).to receive(:info).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob secondary form stuck in non-final error state',
              hash_including(
                secondary_form_uuid: secondary_form.guid,
                appeal_submission_id: secondary_form.appeal_submission_id,
                days_in_error: days_in_error.round(2),
                status_updated_at: frozen_time
              )
            ).once

            Timecop.freeze(frozen_time) do
              subject.new.perform
            end
          end
        end

        context 'when form has permanent error (final_status: true)' do
          let(:permanent_error_status) do
            {
              'status' => 'error',
              'final_status' => true,
              'detail' => 'Permanent error - invalid document'
            }
          end

          before do
            secondary_form.update!(
              status: permanent_error_status.to_json,
              status_updated_at: frozen_time - 20.days
            )
          end

          it 'does not log warning for permanent errors' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(Rails.logger).not_to have_received(:info).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob secondary form stuck in temporary error state',
              anything
            )
          end
        end

        context 'when form has non-error status' do
          let(:processing_status) do
            {
              'status' => 'processing',
              'final_status' => false,
              'detail' => 'Still processing'
            }
          end

          before do
            secondary_form.update!(
              status: processing_status.to_json,
              status_updated_at: frozen_time - 20.days
            )
          end

          it 'does not log warning for non-error statuses' do
            processing_response = instance_double(Faraday::Response, body: {
                                                    'data' => {
                                                      'attributes' => {
                                                        'status' => 'processing',
                                                        'final_status' => false,
                                                        'detail' => 'Still processing',
                                                        'updated_at' => Time.current.iso8601
                                                      }
                                                    }
                                                  })

            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form.guid).and_return(processing_response)

            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(Rails.logger).not_to have_received(:info).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob secondary form stuck in temporary error state',
              anything
            )
          end
        end

        context 'when form transitions from temporary to permanent error (final_status: false -> true)' do
          let(:twenty_days_ago) { frozen_time - 20.days }
          let(:response_error_final) do
            response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
            response['data']['attributes']['status'] = 'error'
            response['data']['attributes']['final_status'] = true
            response['data']['attributes']['detail'] = 'Document processing failed'
            instance_double(Faraday::Response, body: response)
          end

          before do
            secondary_form.update!(
              created_at: twenty_days_ago,
              status: { status: 'error', final_status: false }.to_json,
              status_updated_at: twenty_days_ago
            )
          end

          it 'does NOT log warning when form transitions to final_status: true' do
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form.guid).and_return(response_error_final)

            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(Rails.logger).not_to have_received(:info).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob secondary form stuck in non-final error state',
              anything
            )
          end

          it 'updates the form with final_status: true' do
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form.guid).and_return(response_error_final)

            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            secondary_form.reload
            parsed_status = JSON.parse(secondary_form.status)
            expect(parsed_status['status']).to eq('error')
            expect(parsed_status['final_status']).to be(true)
            expect(parsed_status['detail']).to eq('Document processing failed')
          end

          it 'does not continue polling after transition to final status' do
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: secondary_form.guid).and_return(response_error_final)

            # Run the job twice to ensure polling stops
            Timecop.freeze(frozen_time) do
              subject.new.perform
              subject.new.perform
            end

            # Should only call API once since final_status becomes true
            expect(benefits_intake_service).to have_received(:get_status)
              .with(uuid: secondary_form.guid).once
          end
        end

        context 'multiple forms with mixed statuses' do
          let!(:form_temp_error_old) do
            create(:secondary_appeal_form4142_module,
                   guid: SecureRandom.uuid,
                   appeal_submission: secondary_form.appeal_submission,
                   status: { 'status' => 'error', 'final_status' => false }.to_json,
                   status_updated_at: frozen_time - 20.days,
                   created_at: frozen_time - 20.days)
          end

          let!(:form_temp_error_recent) do
            create(:secondary_appeal_form4142_module,
                   guid: SecureRandom.uuid,
                   appeal_submission: secondary_form.appeal_submission,
                   status: { 'status' => 'error', 'final_status' => false }.to_json,
                   status_updated_at: frozen_time - 5.days,
                   created_at: frozen_time - 5.days)
          end

          let!(:form_permanent_error) do
            create(:secondary_appeal_form4142_module,
                   guid: SecureRandom.uuid,
                   appeal_submission: secondary_form.appeal_submission,
                   status: { 'status' => 'error', 'final_status' => true }.to_json,
                   status_updated_at: frozen_time - 25.days,
                   created_at: frozen_time - 25.days)
          end

          let!(:form_transitioning_to_final) do
            create(:secondary_appeal_form4142_module,
                   guid: SecureRandom.uuid,
                   appeal_submission: secondary_form.appeal_submission,
                   status: { 'status' => 'error', 'final_status' => false }.to_json,
                   status_updated_at: frozen_time - 18.days,
                   created_at: frozen_time - 18.days)
          end

          before do
            response_processing = JSON.parse(
              File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json')
            )
            response_processing['data']['attributes']['status'] = 'processing'
            response_processing['data']['attributes']['final_status'] = false
            processing_response = instance_double(Faraday::Response, body: response_processing)

            response_error_non_final = JSON.parse(
              File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json')
            )
            response_error_non_final['data']['attributes']['status'] = 'error'
            response_error_non_final['data']['attributes']['final_status'] = false
            response_error_non_final['data']['attributes']['detail'] = 'Still in error state'
            error_non_final_response = instance_double(Faraday::Response, body: response_error_non_final)

            response_error_final = JSON.parse(
              File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json')
            )
            response_error_final['data']['attributes']['status'] = 'error'
            response_error_final['data']['attributes']['final_status'] = true
            error_final_response = instance_double(Faraday::Response, body: response_error_final)

            # Default response for most forms
            allow(benefits_intake_service).to receive(:get_status).and_return(processing_response)

            # Specific response for the old temp error form (should trigger warning)
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: form_temp_error_old.guid).and_return(error_non_final_response)

            # Specific response for the transitioning form
            allow(benefits_intake_service).to receive(:get_status)
              .with(uuid: form_transitioning_to_final.guid).and_return(error_final_response)
          end

          it 'only logs warnings for temporary errors exceeding threshold' do
            expect(Rails.logger).to receive(:info).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob secondary form stuck in non-final error state',
              hash_including(secondary_form_uuid: form_temp_error_old.guid)
            ).once

            allow(Rails.logger).to receive(:info).with(
              'SavedClaim::SupplementalClaim Skipping tracking PDF overflow',
              anything
            ).and_call_original

            Timecop.freeze(frozen_time) do
              subject.new.perform
            end
          end

          it 'does not log warnings for forms transitioning to final status during same run' do
            # Should NOT log for the transitioning form even though it's > 15 days old
            expect(Rails.logger).not_to receive(:info).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob secondary form stuck in non-final error state',
              hash_including(secondary_form_uuid: form_transitioning_to_final.guid)
            )

            # Should still log for the form that remains in non-final error state
            expect(Rails.logger).to receive(:info).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob secondary form stuck in non-final error state',
              hash_including(secondary_form_uuid: form_temp_error_old.guid)
            ).once

            allow(Rails.logger).to receive(:info).with(
              'SavedClaim::SupplementalClaim Skipping tracking PDF overflow',
              anything
            ).and_call_original

            Timecop.freeze(frozen_time) do
              subject.new.perform
            end
          end
        end
      end
    end
  end

  # LEGACY POLLING BEHAVIOR (TEMPORARY - Remove when final_status_polling flag removed)
  describe 'legacy secondary form processing', :legacy_polling do
    context 'when enhanced polling is disabled (legacy behavior)', :aggregate_failures do
      let(:benefits_intake_service) { instance_double(BenefitsIntake::Service) }
      let(:frozen_time) { DateTime.new(2024, 1, 1).utc }

      before do
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_saved_claim_sc_status_updater_job_enabled).and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_track_4142_submissions).and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_final_status_polling).and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:saved_claim_pdf_overflow_tracking).and_call_original
        allow(Flipper).to receive(:enabled?)
          .with(:decision_review_stuck_records_monitoring).and_return(false)
        allow(DecisionReviews::V1::Service).to receive(:new).and_return(service)
        allow(BenefitsIntake::Service).to receive(:new).and_return(benefits_intake_service)
        allow(StatsD).to receive(:increment)
        allow(Rails.logger).to receive(:info)
      end

      after do
        benefits_intake_service { nil }
      end

      context 'always makes API calls regardless of stored status' do
        let!(:secondary_form) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:saved_claim) do
          SavedClaim::SupplementalClaim.create(
            guid: secondary_form.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end

        let(:stored_final_status) do
          {
            'status' => 'vbms',
            'final_status' => true,
            'detail' => 'Completed'
          }
        end

        let(:upload_response_vbms) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'vbms'
          instance_double(Faraday::Response, body: response)
        end

        before do
          secondary_form.update!(status: stored_final_status.to_json)
          allow(service).to receive(:get_supplemental_claim)
            .with(saved_claim.guid).and_return(response_complete)
          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: secondary_form.guid).and_return(upload_response_vbms)
        end

        it 'makes API call even when stored status indicates completion' do
          Timecop.freeze(frozen_time) do
            subject.new.perform
          end

          expect(benefits_intake_service).to have_received(:get_status)
            .with(uuid: secondary_form.guid)
        end
      end

      context 'does not store final_status field' do
        let!(:secondary_form) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:saved_claim) do
          SavedClaim::SupplementalClaim.create(
            guid: secondary_form.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end

        let(:upload_response_vbms) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'vbms'
          instance_double(Faraday::Response, body: response)
        end

        before do
          allow(service).to receive(:get_supplemental_claim)
            .with(saved_claim.guid).and_return(response_complete)
          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: secondary_form.guid).and_return(upload_response_vbms)
        end

        it 'stores only legacy status fields (status, detail, updated_at)' do
          Timecop.freeze(frozen_time) do
            subject.new.perform
          end

          parsed_status = JSON.parse(secondary_form.reload.status)
          expect(parsed_status.keys.sort).to eq(%w[detail status updated_at])
          expect(parsed_status).not_to have_key('final_status')
        end
      end

      context 'sets delete_date when status=vbms (regardless of final_status)' do
        let!(:secondary_form) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:saved_claim) do
          SavedClaim::SupplementalClaim.create(
            guid: secondary_form.appeal_submission.submitted_appeal_uuid,
            form: '{}'
          )
        end

        let(:upload_response_vbms) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'vbms'
          instance_double(Faraday::Response, body: response)
        end

        before do
          allow(service).to receive(:get_supplemental_claim)
            .with(saved_claim.guid).and_return(response_complete)
          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: secondary_form.guid).and_return(upload_response_vbms)
        end

        it 'sets delete_date when status is vbms using legacy completion logic' do
          Timecop.freeze(frozen_time) do
            subject.new.perform
          end

          expect(secondary_form.reload.delete_date).to eq(frozen_time + 59.days)
          expect(saved_claim.reload.delete_date).to eq(frozen_time + 59.days)
        end
      end

      context 'legacy status processing' do
        let!(:secondary_form1) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:secondary_form2) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
        let!(:secondary_form3) { create(:secondary_appeal_form4142_module, guid: SecureRandom.uuid) }
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

        let(:upload_response_vbms) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'vbms'
          instance_double(Faraday::Response, body: response)
        end

        let(:upload_response_processing) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'processing'
          instance_double(Faraday::Response, body: response)
        end

        let(:upload_response_error) do
          response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_4142_show_response_200.json'))
          response['data']['attributes']['status'] = 'error'
          response['data']['attributes']['detail'] = 'Invalid PDF'
          instance_double(Faraday::Response, body: response)
        end

        before do
          allow(service).to receive(:get_supplemental_claim).with(saved_claim1.guid).and_return(response_complete)
          allow(service).to receive(:get_supplemental_claim).with(saved_claim2.guid).and_return(response_complete)
          allow(service).to receive(:get_supplemental_claim).with(saved_claim3.guid).and_return(response_complete)

          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: secondary_form1.guid).and_return(upload_response_vbms)
          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: secondary_form2.guid).and_return(upload_response_processing)
          allow(benefits_intake_service).to receive(:get_status)
            .with(uuid: secondary_form3.guid).and_return(upload_response_error)
        end

        it 'updates the status and sets delete_date if appropriate using legacy logic' do
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
      end
    end
  end

  # RECORDS STUCK IN NON-FINAL STATUS MONITORING
  describe 'stuck records monitoring' do
    let(:service) { instance_double(DecisionReviews::V1::Service) }
    let(:frozen_time) { DateTime.new(2024, 1, 15, 10, 0, 0).utc }
    let(:valid_form_data) { VetsJsonSchema::EXAMPLES.fetch('SC-CREATE-REQUEST-BODY_V1').to_json }

    before do
      allow(Flipper).to receive(:enabled?)
                    .with(:decision_review_saved_claim_sc_status_updater_job_enabled).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:decision_review_stuck_records_monitoring).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:decision_review_track_4142_submissions).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_call_original
      allow(DecisionReviews::V1::Service).to receive(:new).and_return(service)
      allow(StatsD).to receive(:increment)
    end

    describe 'monitor_stuck_form_with_metadata' do
      let!(:old_appeal_submission) { create(:appeal_submission) }
      let!(:recent_appeal_submission) { create(:appeal_submission) }

      let!(:old_saved_claim) do
        SavedClaim::SupplementalClaim.create(
          guid: old_appeal_submission.submitted_appeal_uuid,
          form: valid_form_data,
          created_at: frozen_time - 35.days
        )
      end

      let!(:recent_saved_claim) do
        SavedClaim::SupplementalClaim.create(
          guid: recent_appeal_submission.submitted_appeal_uuid,
          form: valid_form_data,
          created_at: frozen_time - 25.days
        )
      end

      let(:response_processing) do
        {
          'data' => {
            'attributes' => {
              'status' => 'processing',
              'detail' => 'Still processing',
              'createDate' => '2024-01-01T00:00:00.000Z',
              'updateDate' => '2024-01-01T10:00:00.000Z'
            }
          }
        }
      end

      let(:response_complete) do
        {
          'data' => {
            'attributes' => {
              'status' => 'complete',
              'detail' => 'Completed successfully',
              'createDate' => '2024-01-01T00:00:00.000Z',
              'updateDate' => '2024-01-01T10:00:00.000Z'
            }
          }
        }
      end

      before do
        allow(service).to receive(:get_supplemental_claim).with(old_saved_claim.guid).and_return(
          instance_double(Faraday::Response, body: response_processing)
        )
        allow(service).to receive(:get_supplemental_claim).with(recent_saved_claim.guid).and_return(
          instance_double(Faraday::Response, body: response_processing)
        )
      end

      context 'when monitoring is enabled' do
        it 'logs warning for forms stuck >30 days in non-final status' do
          Timecop.freeze(frozen_time) do
            expect(Rails.logger).to receive(:warn).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob form stuck in non-final status',
              {
                appeal_submission_id: old_saved_claim.appeal_submission.id,
                days_stuck: 35.0,
                created_at: old_saved_claim.created_at,
                current_status: 'processing'
              }
            )

            subject.new.perform
          end
        end

        it 'does not log for forms more recent than 30 days' do
          Timecop.freeze(frozen_time) do
            expect(Rails.logger).not_to receive(:warn).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob form stuck in non-final status',
              hash_including(appeal_submission_id: recent_saved_claim.appeal_submission.id)
            )

            subject.new.perform
          end
        end

        it 'does not log for forms in final status even if older than 30 days' do
          allow(service).to receive(:get_supplemental_claim).with(old_saved_claim.guid).and_return(
            instance_double(Faraday::Response, body: response_complete)
          )

          Timecop.freeze(frozen_time) do
            expect(Rails.logger).not_to receive(:warn).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob form stuck in non-final status',
              hash_including(appeal_submission_id: old_saved_claim.appeal_submission.id)
            )

            subject.new.perform
          end
        end

        it 'calculates days_stuck correctly using created_at timestamp' do
          old_saved_claim.update!(created_at: frozen_time - 32.5.days)

          Timecop.freeze(frozen_time) do
            expect(Rails.logger).to receive(:warn).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob form stuck in non-final status',
              hash_including(days_stuck: 32.5)
            )

            subject.new.perform
          end
        end
      end

      context 'when monitoring is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:decision_review_stuck_records_monitoring).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:decision_review_track_4142_submissions).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_call_original
        end

        it 'does not log warnings even for stuck forms' do
          Timecop.freeze(frozen_time) do
            expect(Rails.logger).not_to receive(:warn).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob form stuck in non-final status',
              any_args
            )

            subject.new.perform
          end
        end
      end
    end

    describe 'monitor_stuck_evidence_upload' do
      let!(:appeal_submission_old) { create(:appeal_submission) }
      let!(:appeal_submission_recent) { create(:appeal_submission) }

      let!(:old_saved_claim) do
        SavedClaim::SupplementalClaim.create(
          guid: appeal_submission_old.submitted_appeal_uuid,
          form: valid_form_data,
          created_at: frozen_time - 35.days
        )
      end

      let!(:recent_saved_claim) do
        SavedClaim::SupplementalClaim.create(
          guid: appeal_submission_recent.submitted_appeal_uuid,
          form: valid_form_data,
          created_at: frozen_time - 25.days
        )
      end

      let!(:old_upload) do
        create(:appeal_submission_upload,
               appeal_submission: appeal_submission_old,
               lighthouse_upload_id: SecureRandom.uuid)
      end

      let!(:recent_upload) do
        create(:appeal_submission_upload,
               appeal_submission: appeal_submission_recent,
               lighthouse_upload_id: SecureRandom.uuid)
      end

      let(:response_complete) do
        {
          'data' => {
            'attributes' => {
              'status' => 'complete',
              'detail' => 'Completed successfully',
              'createDate' => '2024-01-01T00:00:00.000Z',
              'updateDate' => '2024-01-01T10:00:00.000Z'
            }
          }
        }
      end

      let(:upload_response_processing) do
        {
          'data' => {
            'attributes' => {
              'status' => 'processing',
              'detail' => 'Still processing',
              'createDate' => '2024-01-01T00:00:00.000Z',
              'updateDate' => '2024-01-01T10:00:00.000Z'
            }
          }
        }
      end

      let(:upload_response_vbms) do
        {
          'data' => {
            'attributes' => {
              'status' => 'vbms',
              'detail' => 'Successfully uploaded',
              'createDate' => '2024-01-01T00:00:00.000Z',
              'updateDate' => '2024-01-01T10:00:00.000Z'
            }
          }
        }
      end

      before do
        allow(service).to receive(:get_supplemental_claim).with(old_saved_claim.guid).and_return(
          instance_double(Faraday::Response, body: response_complete)
        )
        allow(service).to receive(:get_supplemental_claim).with(recent_saved_claim.guid).and_return(
          instance_double(Faraday::Response, body: response_complete)
        )

        allow(service).to receive(:get_supplemental_claim_upload)
                      .with(guid: old_upload.lighthouse_upload_id).and_return(
                        instance_double(Faraday::Response, body: upload_response_processing)
                      )
        allow(service).to receive(:get_supplemental_claim_upload)
                      .with(guid: recent_upload.lighthouse_upload_id).and_return(
                        instance_double(Faraday::Response, body: upload_response_processing)
                      )
      end

      context 'when monitoring is enabled' do
        it 'logs warning for evidence uploads stuck >30 days in non-final status' do
          Timecop.freeze(frozen_time) do
            expect(Rails.logger).to receive(:warn).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob evidence stuck in non-final status',
              {
                appeal_submission_id: old_saved_claim.appeal_submission.id,
                days_stuck: 35.0,
                created_at: old_saved_claim.created_at,
                current_status: 'processing',
                upload_id: old_upload.lighthouse_upload_id
              }
            )

            subject.new.perform
          end
        end

        it 'does not log for evidence uploads more recent than 30 days' do
          Timecop.freeze(frozen_time) do
            expect(Rails.logger).not_to receive(:warn).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob evidence stuck in non-final status',
              hash_including(upload_id: recent_upload.lighthouse_upload_id)
            )

            subject.new.perform
          end
        end

        it 'does not log for evidence uploads in final status even if older than 30 days' do
          allow(service).to receive(:get_supplemental_claim_upload)
                        .with(guid: old_upload.lighthouse_upload_id).and_return(
                          instance_double(Faraday::Response, body: upload_response_vbms)
                        )

          Timecop.freeze(frozen_time) do
            expect(Rails.logger).not_to receive(:warn).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob evidence stuck in non-final status',
              hash_including(upload_id: old_upload.lighthouse_upload_id)
            )

            subject.new.perform
          end
        end

        it 'logs for multiple stuck evidence uploads on same form' do
          second_old_upload = create(:appeal_submission_upload, appeal_submission: appeal_submission_old)

          allow(service).to receive(:get_supplemental_claim_upload)
                        .with(guid: second_old_upload.lighthouse_upload_id).and_return(
                          instance_double(Faraday::Response, body: upload_response_processing)
                        )

          Timecop.freeze(frozen_time) do
            expect(Rails.logger).to receive(:warn).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob evidence stuck in non-final status',
              hash_including(upload_id: old_upload.lighthouse_upload_id)
            )

            expect(Rails.logger).to receive(:warn).with(
              'DecisionReviews::SavedClaimScStatusUpdaterJob evidence stuck in non-final status',
              hash_including(upload_id: second_old_upload.lighthouse_upload_id)
            )

            subject.new.perform
          end
        end

        context 'when monitoring is disabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:decision_review_stuck_records_monitoring).and_return(false)
            allow(Flipper).to receive(:enabled?).with(:decision_review_track_4142_submissions).and_return(false)
            allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_call_original
          end

          it 'does not log warnings even for stuck evidence uploads' do
            Timecop.freeze(frozen_time) do
              expect(Rails.logger).not_to receive(:warn).with(
                'DecisionReviews::SavedClaimScStatusUpdaterJob evidence stuck in non-final status',
                any_args
              )

              subject.new.perform
            end
          end
        end
      end

      describe 'monitoring integration with existing job flow' do
        let!(:appeal_submission) { create(:appeal_submission) }
        let!(:stuck_saved_claim) do
          SavedClaim::SupplementalClaim.create(
            guid: appeal_submission.submitted_appeal_uuid,
            form: valid_form_data,
            created_at: frozen_time - 35.days
          )
        end
        let!(:stuck_upload) do
          create(:appeal_submission_upload,
                 appeal_submission:,
                 lighthouse_upload_id: SecureRandom.uuid)
        end

        let(:response_processing) do
          {
            'data' => {
              'attributes' => {
                'status' => 'processing',
                'detail' => 'Still processing',
                'createDate' => '2024-01-01T00:00:00.000Z',
                'updateDate' => '2024-01-01T10:00:00.000Z'
              }
            }
          }
        end

        let(:upload_response_processing) do
          {
            'data' => {
              'attributes' => {
                'status' => 'processing',
                'detail' => 'Still processing upload',
                'createDate' => '2024-01-01T00:00:00.000Z',
                'updateDate' => '2024-01-01T10:00:00.000Z'
              }
            }
          }
        end

        before do
          allow(service).to receive(:get_supplemental_claim).with(stuck_saved_claim.guid).and_return(
            instance_double(Faraday::Response, body: response_processing)
          )
          allow(service).to receive(:get_supplemental_claim_upload)
            .with(guid: stuck_upload.lighthouse_upload_id).and_return(
              instance_double(Faraday::Response, body: upload_response_processing)
            )
        end

        it 'does not affect delete_date logic when monitoring detects stuck records' do
          Timecop.freeze(frozen_time) do
            subject.new.perform

            stuck_saved_claim.reload

            expect(stuck_saved_claim.delete_date).to be_nil
          end
        end
      end
    end
  end
end
