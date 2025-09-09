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
        allow(DecisionReviews::V1::Service).to receive(:new).and_return(service)
        allow(BenefitsIntake::Service).to receive(:new).and_return(benefits_intake_service)
        allow(StatsD).to receive(:increment)
        allow(Rails.logger).to receive(:info)
      end

      after do
        benefits_intake_service { nil }
      end

      context 'when forms have final_status = true in stored status' do
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

        it 'does NOT make API call and uses stored data' do
          Timecop.freeze(frozen_time) do
            subject.new.perform
          end

          expect(benefits_intake_service).not_to have_received(:get_status)
            .with(uuid: secondary_form.guid)
          expect(secondary_form.reload.status_updated_at).to eq(frozen_time)
          expect(secondary_form.reload.delete_date).to eq(frozen_time + 59.days)
        end

        it 'marks record as complete when using stored final status' do
          Timecop.freeze(frozen_time) do
            subject.new.perform
          end

          saved_claim.reload
          expect(saved_claim.delete_date).to eq(frozen_time + 59.days)
        end
      end

      context 'when forms have final_status = false in stored status' do
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

          it 'does not set delete_date despite being final' do
            Timecop.freeze(frozen_time) do
              subject.new.perform
            end

            expect(secondary_form.reload.delete_date).to be_nil
            parsed_status = JSON.parse(secondary_form.reload.status)

            expect(parsed_status['final_status']).to be(false)
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

        context 'when one form has recoverable error (active mitigation scenario)' do
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

          it 'does not mark record as complete and continues mitigation' do
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
end
