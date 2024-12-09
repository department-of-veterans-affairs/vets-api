# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'
require 'virtual_regional_office/client'

# pulled from vets-api/spec/support/disability_compensation_form/submissions/only_526.json
ONLY_526_JSON_CLASSIFICATION_CODE = 'string'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm526AllClaim, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    Flipper.disable(:disability_compensation_lighthouse_claims_service_provider)
    Flipper.disable(:disability_compensation_production_tester)
    Flipper.disable(:disability_compensation_fail_submission)
    Flipper.disable(:disability_526_expanded_contention_classification)
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  describe '.perform_async' do
    define_negated_matcher :not_change, :change

    let(:saved_claim) { FactoryBot.create(:va526ez) }
    let(:submitted_claim_id) { 600_130_094 }
    let(:user_account) { create(:user_account, icn: '123498767V234859') }
    let(:submission) do
      create(:form526_submission,
             user_account_id: user_account.id,
             user_uuid: user.uuid,
             auth_headers_json: auth_headers.to_json,
             saved_claim_id: saved_claim.id)
    end
    let(:open_claims_cassette) { 'evss/claims/claims_without_open_compensation_claims' }
    let(:caseflow_cassette) { 'caseflow/appeals' }
    let(:rated_disabilities_cassette) { 'evss/disability_compensation_form/rated_disabilities' }
    let(:submit_form_cassette) { 'evss/disability_compensation_form/submit_form_v2' }
    let(:lh_upload) { 'lighthouse/benefits_intake/200_lighthouse_intake_upload_location' }
    let(:evss_get_pdf) { 'form526_backup/200_evss_get_pdf' }
    let(:lh_intake_upload) { 'lighthouse/benefits_intake/200_lighthouse_intake_upload' }
    let(:lh_submission) { 'lighthouse/benefits_claims/submit526/200_synchronous_response' }
    let(:cassettes) do
      [open_claims_cassette, caseflow_cassette, rated_disabilities_cassette,
       submit_form_cassette, lh_upload, evss_get_pdf,
       lh_intake_upload, lh_submission]
    end
    let(:backup_klass) { Sidekiq::Form526BackupSubmissionProcess::Submit }

    before do
      cassettes.each { |cassette| VCR.insert_cassette(cassette) }
      Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_BACKGROUND)
      Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_FOREGROUND)
    end

    after do
      cassettes.each { |cassette| VCR.eject_cassette(cassette) }
    end

    def expect_retryable_error(error_class)
      subject.perform_async(submission.id)
      expect_any_instance_of(Sidekiq::Form526JobStatusTracker::Metrics).to receive(:increment_retryable).once
      expect(Form526JobStatus).to receive(:upsert).twice
      expect do
        described_class.drain
      end.to raise_error(error_class).and not_change(backup_klass.jobs, :size)
    end

    def expect_non_retryable_error
      subject.perform_async(submission.id)
      expect_any_instance_of(Sidekiq::Form526JobStatusTracker::Metrics).to receive(:increment_non_retryable).once
      expect(Form526JobStatus).to receive(:upsert).thrice
      expect_any_instance_of(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim).to(
        receive(:non_retryable_error_handler).and_call_original
      )
      described_class.drain
    end

    context 'Submission inspection for flashes' do
      before do
        allow(Rails.logger).to receive(:info)
        allow(StatsD).to receive(:increment)
      end

      def submit_it
        subject.perform_async(submission.id)
        VCR.use_cassette('virtual_regional_office/contention_classification_null_response') do
          described_class.drain
        end
        submission.reload
        expect(Form526JobStatus.last.status).to eq 'success'
      end

      context 'without any flashes' do
        let(:submission) do
          create(:form526_submission,
                 :asthma_claim_for_increase,
                 user_uuid: user.uuid,
                 auth_headers_json: auth_headers.to_json,
                 saved_claim_id: saved_claim.id)
        end

        it 'does not log or push metrics' do
          submit_it

          expect(Rails.logger).not_to have_received(:info).with('Flash Prototype Added', anything)
          expect(StatsD).not_to have_received(:increment).with('worker.flashes', anything)
        end
      end

      context 'with flash but without prototype' do
        let(:submission) do
          create(:form526_submission,
                 :without_diagnostic_code,
                 user_uuid: user.uuid,
                 auth_headers_json: auth_headers.to_json,
                 saved_claim_id: saved_claim.id)
        end

        it 'does not log prototype statement but pushes metrics' do
          submit_it

          expect(Rails.logger).not_to have_received(:info).with('Flash Prototype Added', anything)
          expect(StatsD).to have_received(:increment).with(
            'worker.flashes',
            tags: ['flash:Priority Processing - Veteran over age 85', 'prototype:false']
          ).once
        end
      end

      context 'with ALS flash' do
        let(:submission) do
          create(:form526_submission,
                 :als_claim_for_increase,
                 user_uuid: user.uuid,
                 auth_headers_json: auth_headers.to_json,
                 saved_claim_id: saved_claim.id)
        end

        it 'logs prototype statement and pushes metrics' do
          submit_it

          expect(Rails.logger).to have_received(:info).with(
            'Flash Prototype Added',
            { submitted_claim_id:, flashes: ['Amyotrophic Lateral Sclerosis'] }
          ).once
          expect(StatsD).to have_received(:increment).with(
            'worker.flashes',
            tags: ['flash:Amyotrophic Lateral Sclerosis', 'prototype:true']
          ).once
        end
      end

      context 'with multiple flashes' do
        let(:submission) do
          create(:form526_submission,
                 :als_claim_for_increase_terminally_ill,
                 user_uuid: user.uuid,
                 auth_headers_json: auth_headers.to_json,
                 saved_claim_id: saved_claim.id)
        end

        it 'logs prototype statement and pushes metrics' do
          submit_it

          expect(Rails.logger).to have_received(:info).with(
            'Flash Prototype Added',
            { submitted_claim_id:, flashes: ['Amyotrophic Lateral Sclerosis', 'Terminally Ill'] }
          ).once
          expect(StatsD).to have_received(:increment).with(
            'worker.flashes',
            tags: ['flash:Amyotrophic Lateral Sclerosis', 'prototype:true']
          ).once
          expect(StatsD).to have_received(:increment).with(
            'worker.flashes',
            tags: ['flash:Terminally Ill', 'prototype:false']
          ).once
        end
      end
    end

    context 'with contention classification enabled' do
      context 'when diagnostic code is not set' do
        let(:submission) do
          create(:form526_submission,
                 :without_diagnostic_code,
                 user_uuid: user.uuid,
                 auth_headers_json: auth_headers.to_json,
                 saved_claim_id: saved_claim.id)
        end
      end

      context 'when diagnostic code is set' do
        it 'still completes form 526 submission when CC fails' do
          subject.perform_async(submission.id)
          expect do
            VCR.use_cassette('virtual_regional_office/contention_classification_failure') do
              described_class.drain
            end
          end.not_to change(backup_klass.jobs, :size)
          expect(Form526JobStatus.last.status).to eq 'success'
        end

        it 'handles null response gracefully' do
          subject.perform_async(submission.id)
          expect do
            VCR.use_cassette('virtual_regional_office/contention_classification_null_response') do
              described_class.drain
              submission.reload

              final_classification_code = submission.form['form526']['form526']['disabilities'][0]['classificationCode']
              expect(final_classification_code).to eq(ONLY_526_JSON_CLASSIFICATION_CODE)
            end
          end.not_to change(Sidekiq::Form526BackupSubmissionProcess::Submit.jobs, :size)
          expect(Form526JobStatus.last.status).to eq 'success'
        end

        it 'updates Form526Submission form with id' do
          expect(described_class).to be < EVSS::DisabilityCompensationForm::SubmitForm526
          subject.perform_async(submission.id)

          expect do
            VCR.use_cassette('virtual_regional_office/fully_classified_contention_classification') do
              described_class.drain
              submission.reload

              final_classification_code = submission.form['form526']['form526']['disabilities'][0]['classificationCode']
              expect(final_classification_code).to eq(9012)
            end
          end.not_to change(Sidekiq::Form526BackupSubmissionProcess::Submit.jobs, :size)
        end

        context 'when veteran has open claims' do
          let(:open_claims_cassette) { 'evss/claims/claims' }

          before do
            allow(Rails.logger).to receive(:info)
            Timecop.freeze('2018-09-28T13:00:00ZZ')
          end

          after { Timecop.return }

          it 'logs the expected data for EP 400 merge eligibility' do
            subject.perform_async(submission.id)
            VCR.use_cassette('virtual_regional_office/fully_classified_contention_classification') do
              described_class.drain
            end
            expect(Rails.logger).to have_received(:info).with('EP Merge total open EPs', id: submission.id, count: 1)
            expect(Rails.logger).to have_received(:info).with(
              'EP Merge open EP eligibility',
              { id: submission.id, feature_enabled: true, open_claim_review: false,
                pending_ep_age: 365, pending_ep_status: 'UNDER REVIEW' }
            )
          end

          context 'when the claim is not fully classified' do
            it 'does not log EP 400 merge eligibility' do
              subject.perform_async(submission.id)
              VCR.use_cassette('virtual_regional_office/multi_contention_classification') do
                described_class.drain
              end
              expect(Rails.logger).not_to have_received(:info).with(
                'EP Merge total open EPs', id: submission.id, count: 1
              )
              expect(Rails.logger).not_to have_received(:info).with(
                'EP Merge open EP eligibility',
                { id: submission.id, feature_enabled: true, open_claim_review: false,
                  pending_ep_age: 365, pending_ep_status: 'UNDER REVIEW' }
              )
            end
          end

          context 'when using LH Benefits Claims API instead of EVSS' do
            before do
              Flipper.enable(:disability_compensation_lighthouse_claims_service_provider)
              allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return('access_token')
            end

            after { Flipper.disable(:disability_compensation_lighthouse_claims_service_provider) }

            let(:open_claims_cassette) { 'lighthouse/benefits_claims/index/claims_with_single_open_disability_claim' }

            it 'logs the expected data for EP 400 merge eligibility' do
              subject.perform_async(submission.id)
              VCR.use_cassette('virtual_regional_office/fully_classified_contention_classification') do
                described_class.drain
              end
              expect(Rails.logger).to have_received(:info).with('EP Merge total open EPs', id: submission.id, count: 1)
              expect(Rails.logger).to have_received(:info).with(
                'EP Merge open EP eligibility',
                { id: submission.id, feature_enabled: true, open_claim_review: false,
                  pending_ep_age: 365, pending_ep_status: 'INITIAL_REVIEW' }
              )
            end

            context 'when the claim is not fully classified' do
              it 'does not log EP 400 merge eligibility' do
                subject.perform_async(submission.id)
                VCR.use_cassette('virtual_regional_office/multi_contention_classification') do
                  described_class.drain
                end
                expect(Rails.logger).not_to have_received(:info).with(
                  'EP Merge total open EPs', id: submission.id, count: 1
                )
                expect(Rails.logger).not_to have_received(:info).with(
                  'EP Merge open EP eligibility',
                  { id: submission.id, feature_enabled: true, open_claim_review: false,
                    pending_ep_age: 365, pending_ep_status: 'INITIAL_REVIEW' }
                )
              end
            end
          end

          context 'when EP400 merge API call is enabled' do
            before do
              Flipper.enable(:disability_526_ep_merge_api, user)
              allow(Flipper).to receive(:enabled?).and_call_original
            end

            it 'records the eligible claim ID and adds the EP400 special issue to the submission' do
              subject.perform_async(submission.id)
              VCR.use_cassette('virtual_regional_office/fully_classified_contention_classification') do
                described_class.drain
              end
              submission.reload
              expect(submission.read_metadata(:ep_merge_pending_claim_id)).to eq('600114692') # from claims.yml
              expect(submission.disabilities.first).to include('specialIssues' => ['EMP'])
              actor = OpenStruct.new({ flipper_id: submission.user_uuid })
              expect(Flipper).to have_received(:enabled?).with(:disability_526_ep_merge_api, actor).once
            end

            context 'when the claim is not fully classified' do
              it 'does not record an eligible claim id' do
                subject.perform_async(submission.id)
                VCR.use_cassette('virtual_regional_office/multi_contention_classification') do
                  described_class.drain
                end
                submission.reload
                expect(submission.read_metadata(:ep_merge_pending_claim_id)).to be_nil
                expect(submission.disabilities.first['specialIssues']).to be_nil
              end
            end
          end

          context 'when pending claim has lifecycle status not considered open for EP400 merge' do
            let(:open_claims_cassette) { 'evss/claims/claims_pending_decision_approval' }

            it 'does not save any claim ID for EP400 merge' do
              subject.perform_async(submission.id)
              VCR.use_cassette('virtual_regional_office/fully_classified_contention_classification') do
                described_class.drain
              end
              submission.reload
              expect(submission.read_metadata(:ep_merge_pending_claim_id)).to be_nil
            end
          end

          context 'when an EP 030 or 040 is included in the list of open claims' do
            let(:open_claims_cassette) { 'evss/claims/claims_with_open_040' }

            it 'does not save any claim ID for EP400 merge' do
              subject.perform_async(submission.id)
              VCR.use_cassette('virtual_regional_office/fully_classified_contention_classification') do
                described_class.drain
              end
              submission.reload
              expect(submission.read_metadata(:ep_merge_pending_claim_id)).to be_nil
            end
          end

          context 'when Caseflow appeals status API returns an open claim review' do
            let(:caseflow_cassette) { 'caseflow/appeals_with_hlr_only' }

            it 'does not save any claim ID for EP400 merge' do
              subject.perform_async(submission.id)
              VCR.use_cassette('virtual_regional_office/fully_classified_contention_classification') do
                described_class.drain
              end
              submission.reload
              expect(submission.read_metadata(:ep_merge_pending_claim_id)).to be_nil
            end
          end

          context 'when EP400 merge API call is disabled' do
            before { Flipper.disable(:disability_526_ep_merge_api) }

            it 'does not record any eligible claim ID or add an EP400 special issue to the submission' do
              subject.perform_async(submission.id)
              VCR.use_cassette('virtual_regional_office/fully_classified_contention_classification') do
                described_class.drain
              end
              submission.reload
              expect(submission.read_metadata(:ep_merge_pending_claim_id)).to be_nil
              expect(submission.disabilities.first['specialIssues']).to be_nil
            end
          end
        end
      end
    end

    context 'with multi-contention classification enabled' do
      let(:submission) do
        create(:form526_submission,
               :with_mixed_action_disabilities_and_free_text,
               user_uuid: user.uuid,
               auth_headers_json: auth_headers.to_json,
               saved_claim_id: saved_claim.id)
      end

      it 'does something when multi-contention api endpoint is hit' do
        subject.perform_async(submission.id)

        expect do
          VCR.use_cassette('virtual_regional_office/multi_contention_classification') do
            described_class.drain
          end
        end.not_to change(Sidekiq::Form526BackupSubmissionProcess::Submit.jobs, :size)
        submission.reload

        classification_codes = submission.form['form526']['form526']['disabilities'].pluck('classificationCode')
        expect(classification_codes).to eq([9012, 8994, nil, nil])
      end

      it 'calls va-gov-claim-classifier as default' do
        vro_client_mock = instance_double(VirtualRegionalOffice::Client)
        allow(VirtualRegionalOffice::Client).to receive(:new).and_return(vro_client_mock)
        allow(vro_client_mock).to receive_messages(
          classify_vagov_contentions_expanded: OpenStruct.new(body: 'expanded classification'),
          classify_vagov_contentions: OpenStruct.new(body: 'regular response')
        )

        expect_any_instance_of(Form526Submission).to receive(:classify_vagov_contentions).and_call_original
        expect(vro_client_mock).to receive(:classify_vagov_contentions)
        subject.perform_async(submission.id)
        described_class.drain
      end

      context 'when the expanded classification endpoint is enabled' do
        before do
          user = OpenStruct.new({ flipper_id: submission.user_uuid })
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:disability_526_expanded_contention_classification,
                                                    user).and_return(true)
        end

        it 'calls the expanded classification endpoint' do
          vro_client_mock = instance_double(VirtualRegionalOffice::Client)
          allow(VirtualRegionalOffice::Client).to receive(:new).and_return(vro_client_mock)
          allow(vro_client_mock).to receive_messages(
            classify_vagov_contentions_expanded: OpenStruct.new(body: 'expanded classification'),
            classify_vagov_contentions: OpenStruct.new(body: 'regular response')
          )

          expect_any_instance_of(Form526Submission).to receive(:classify_vagov_contentions).and_call_original
          expect(vro_client_mock).to receive(:classify_vagov_contentions_expanded)
          subject.perform_async(submission.id)
          described_class.drain
        end

        it 'uses expanded classification to classify contentions' do
          subject.perform_async(submission.id)
          expect do
            VCR.use_cassette('virtual_regional_office/expanded_classification') do
              described_class.drain
            end
          end.not_to change(Sidekiq::Form526BackupSubmissionProcess::Submit.jobs, :size)
          submission.reload

          classification_codes = submission.form['form526']['form526']['disabilities'].pluck('classificationCode')
          expect(classification_codes).to eq([9012, 8994, nil, 8997])
        end
      end

      context 'when the disabilities array is empty' do
        before do
          allow(Rails.logger).to receive(:info)
        end

        let(:submission) do
          create(:form526_submission,
                 :with_empty_disabilities,
                 user_uuid: user.uuid,
                 auth_headers_json: auth_headers.to_json,
                 saved_claim_id: saved_claim.id)
        end

        it 'returns false to skip classification and continue other jobs' do
          subject.perform_async(submission.id)
          expect(submission.update_contention_classification_all!).to eq false
          expect(Rails.logger).to have_received(:info).with(
            "No disabilities found for classification on claim #{submission.id}"
          )
        end

        it 'does not call va-gov-claim-classifier' do
          subject.perform_async(submission.id)
          described_class.drain
          expect(submission).not_to receive(:classify_vagov_contentions)
        end
      end
    end

    context 'with a successful submission job' do
      it 'queues a job for submit' do
        expect do
          subject.perform_async(submission.id)
        end.to change(subject.jobs, :size).by(1)
      end

      it 'submits successfully' do
        subject.perform_async(submission.id)
        expect { described_class.drain }.not_to change(backup_klass.jobs, :size)
        expect(Form526JobStatus.last.status).to eq 'success'
      end

      it 'submits successfully without calling classification service' do
        subject.perform_async(submission.id)
        expect do
          VCR.use_cassette('virtual_regional_office/multi_contention_classification') do
            described_class.drain
          end
        end.not_to change(backup_klass.jobs, :size)
        expect(Form526JobStatus.last.status).to eq 'success'
      end

      it 'does not call contention classification endpoint' do
        subject.perform_async(submission.id)
        expect(submission).not_to receive(:classify_vagov_contentions)
        described_class.drain
      end

      context 'with an MAS-related diagnostic code' do
        let(:submission) do
          create(:form526_submission,
                 :non_rrd_with_mas_diagnostic_code,
                 user_uuid: user.uuid,
                 auth_headers_json: auth_headers.to_json,
                 saved_claim_id: saved_claim.id)
        end
        let(:mas_cassette) { 'mail_automation/mas_initiate_apcas_request' }
        let(:cassettes) do
          [open_claims_cassette, rated_disabilities_cassette, submit_form_cassette, mas_cassette]
        end

        before do
          allow(StatsD).to receive(:increment)
        end

        it 'sends form526 to the MAS endpoint successfully' do
          subject.perform_async(submission.id)
          described_class.drain
          expect(Form526JobStatus.last.status).to eq 'success'
          rrd_submission = Form526Submission.find(Form526JobStatus.last.form526_submission_id)
          expect(rrd_submission.form.dig('rrd_metadata', 'mas_packetId')).to eq '12345'
          expect(StatsD).to have_received(:increment).with('worker.rapid_ready_for_decision.notify_mas.success').once
        end

        it 'sends an email for tracking purposes' do
          subject.perform_async(submission.id)
          described_class.drain
          expect(ActionMailer::Base.deliveries.last.subject).to eq 'MA claim - 6847'
        end

        context 'when MAS endpoint handshake fails' do
          let(:mas_cassette) { 'mail_automation/mas_initiate_apcas_request_failure' }

          it 'handles MAS endpoint handshake failure by sending failure notification' do
            subject.perform_async(submission.id)
            described_class.drain
            expect(ActionMailer::Base.deliveries.last.subject).to eq "Failure: MA claim - #{submitted_claim_id}"
            expect(StatsD).to have_received(:increment).with('worker.rapid_ready_for_decision.notify_mas.failure').once
          end
        end

        context 'MAS-related claim that already includes classification code' do
          let(:submission) do
            create(:form526_submission,
                   :mas_diagnostic_code_with_classification,
                   user_uuid: user.uuid,
                   auth_headers_json: auth_headers.to_json,
                   saved_claim_id: saved_claim.id)
          end

          it 'already includes classification code and does not modify' do
            subject.perform_async(submission.id)
            described_class.drain
            mas_submission = Form526Submission.find(Form526JobStatus.last.form526_submission_id)
            expect(mas_submission.form.dig('form526', 'form526',
                                           'disabilities').first['classificationCode']).to eq '8935'
          end
        end

        context 'when the rated disability has decision code NOTSVCCON in EVSS' do
          let(:rated_disabilities_cassette) do
            'evss/disability_compensation_form/rated_disabilities_with_non_service_connected'
          end

          it 'skips forwarding to MAS' do
            subject.perform_async(submission.id)
            described_class.drain
            expect(Form526JobStatus.last.status).to eq 'success'
            rrd_submission = Form526Submission.find(submission.id)
            expect(rrd_submission.form.dig('rrd_metadata', 'mas_packetId')).to be_nil
          end
        end
      end

      context 'with multiple MAS-related diagnostic codes' do
        let(:submission) do
          create(:form526_submission,
                 :with_multiple_mas_diagnostic_code,
                 user_uuid: user.uuid,
                 auth_headers_json: auth_headers.to_json,
                 saved_claim_id: saved_claim.id)
        end

        context 'when tracking and APCAS notification are enabled for all claims' do
          it 'calls APCAS and sends two emails' do
            VCR.use_cassette('mail_automation/mas_initiate_apcas_request') do
              subject.perform_async(submission.id)
            end
            described_class.drain
            expect(ActionMailer::Base.deliveries.length).to eq 2
          end
        end
      end

      context 'with Lighthouse as submission provider' do
        let(:submission) do
          create(:form526_submission,
                 :with_everything,
                 user_uuid: user.uuid,
                 auth_headers_json: auth_headers.to_json,
                 saved_claim_id: saved_claim.id,
                 submit_endpoint: 'claims_api')
        end

        let(:headers) { { 'content-type' => 'application/json' } }

        before do
          allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')
        end

        it 'performs a successful submission' do
          subject.perform_async(submission.id)
          expect { described_class.drain }.not_to change(backup_klass.jobs, :size)
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:success]
          submission.reload
          expect(submission.submitted_claim_id).to eq(Form526JobStatus.last.submission.submitted_claim_id)
        end

        it 'retries UpstreamUnprocessableEntity errors' do
          body = { 'errors' => [{ 'status' => '422', 'title' => 'Backend Service Exception',
                                  'detail' => 'The claim failed to establish' }] }

          allow_any_instance_of(BenefitsClaims::Service).to receive(:prepare_submission_body)
            .and_raise(Faraday::UnprocessableEntityError.new(
                         body:,
                         status: 422,
                         headers:
                       ))
          expect_retryable_error(Common::Exceptions::UpstreamUnprocessableEntity)
        end

        it 'does not retry UnprocessableEntity errors with "pointer" defined' do
          body = { 'errors' => [{ 'status' => '422', 'title' => 'Backend Service Exception',
                                  'detail' => 'The claim failed to establish',
                                  'source' => { 'pointer' => 'data/attributes/' } }] }
          allow_any_instance_of(BenefitsClaims::Service).to receive(:prepare_submission_body)
            .and_raise(Faraday::UnprocessableEntityError.new(
                         body:, status: 422, headers:
                       ))
          expect_non_retryable_error
        end

        it 'does not retry UnprocessableEntity errors with "retries will fail" in detail message' do
          body = { 'errors' => [{ 'status' => '422', 'title' => 'Backend Service Exception',
                                  'detail' => 'The claim failed to establish. rEtries WilL fAiL.' }] }
          allow_any_instance_of(BenefitsClaims::Service).to receive(:prepare_submission_body)
            .and_raise(Faraday::UnprocessableEntityError.new(
                         body:, status: 422, headers:
                       ))
          expect_non_retryable_error
        end

        Lighthouse::ServiceException::ERROR_MAP.slice(429, 499, 500, 501, 502, 503).each do |status, error_class|
          it "throws a #{status} error if Lighthouse sends it back" do
            allow_any_instance_of(Form526Submission).to receive(:prepare_for_evss!).and_return(nil)
            allow_any_instance_of(BenefitsClaims::Service).to receive(:prepare_submission_body)
              .and_raise(error_class.new(status:))
            expect_retryable_error(error_class)
          end

          it "throws a #{status} error if Lighthouse sends it back for rated disabilities" do
            allow_any_instance_of(Flipper)
              .to(receive(:enabled?))
              .with('disability_compensation_lighthouse_rated_disabilities_provider_background', anything)
              .and_return(true)
            allow_any_instance_of(EVSS::DisabilityCompensationForm::SubmitForm526)
              .to(receive(:fail_submission_feature_enabled?))
              .and_return(false)
            allow_any_instance_of(Form526ClaimFastTrackingConcern).to receive(:prepare_for_ep_merge!).and_return(nil)
            allow_any_instance_of(Form526ClaimFastTrackingConcern).to receive(:pending_eps?).and_return(false)
            allow_any_instance_of(Form526ClaimFastTrackingConcern).to receive(:classify_vagov_contentions)
              .and_return(nil)
            allow_any_instance_of(VeteranVerification::Service).to receive(:get_rated_disabilities)
              .and_raise(error_class.new(status:))
            expect_retryable_error(error_class)
          end
        end
      end
    end

    context 'with non-MAS-related diagnostic code' do
      let(:submission) do
        create(:form526_submission,
               :with_uploads,
               user_uuid: user.uuid,
               auth_headers_json: auth_headers.to_json,
               saved_claim_id: saved_claim.id)
      end

      it 'does not set a classification code for irrelevant claims' do
        subject.perform_async(submission.id)
        described_class.drain
        mas_submission = Form526Submission.find(Form526JobStatus.last.form526_submission_id)
        expect(mas_submission.form.dig('form526', 'form526',
                                       'disabilities').first['classificationCode']).to eq '8935'
      end
    end

    context 'when retrying a job' do
      it 'doesnt recreate the job status' do
        subject.perform_async(submission.id)

        jid = subject.jobs.last['jid']
        values = {
          form526_submission_id: submission.id,
          job_id: jid,
          job_class: subject.class,
          status: Form526JobStatus::STATUS[:try],
          updated_at: Time.now.utc
        }
        Form526JobStatus.upsert(values, unique_by: :job_id)
        expect_any_instance_of(Sidekiq::Form526JobStatusTracker::Metrics).to(
          receive(:increment_success).with(false, 'evss').once
        )
        described_class.drain
        job_status = Form526JobStatus.where(job_id: values[:job_id]).first
        expect(job_status.status).to eq 'success'
        expect(job_status.error_class).to eq nil
        expect(job_status.job_class).to eq 'SubmitForm526AllClaim'
        expect(Form526JobStatus.count).to eq 1
      end
    end

    context 'with an upstream service error for EP code not valid' do
      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_200_with_ep_not_valid') do
          subject.perform_async(submission.id)
          expect_any_instance_of(Sidekiq::Form526JobStatusTracker::Metrics).to receive(:increment_non_retryable).once
          expect { described_class.drain }.to change(backup_klass.jobs, :size).by(1)
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
          expect(backup_klass.jobs.last['class']).to eq(backup_klass.to_s)
        end
      end
    end

    context 'with a max ep code server error' do
      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_max_ep_code') do
          subject.perform_async(submission.id)
          expect_any_instance_of(Sidekiq::Form526JobStatusTracker::Metrics).to receive(:increment_non_retryable).once
          expect { described_class.drain }.to change(backup_klass.jobs, :size).by(1)
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
          expect(backup_klass.jobs.last['class']).to eq(backup_klass.to_s)
        end
      end
    end

    context 'with a unused [418] error' do
      it 'sets the transaction to "retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_200_with_418') do
          backup_jobs_count = backup_klass.jobs.count
          subject.perform_async(submission.id)
          expect_any_instance_of(Sidekiq::Form526JobStatusTracker::Metrics).to receive(:increment_retryable).once
          expect { described_class.drain }.to raise_error(EVSS::DisabilityCompensationForm::ServiceException)
            .and not_change(backup_klass.jobs, :size)
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:retryable_error]
          expect(backup_klass.jobs.count).to eq(backup_jobs_count)
        end
      end
    end

    context 'with a BGS error' do
      it 'sets the transaction to "retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_200_with_bgs_error') do
          subject.perform_async(submission.id)
          expect_any_instance_of(Sidekiq::Form526JobStatusTracker::Metrics).to receive(:increment_retryable).once
          expect { described_class.drain }.to raise_error(EVSS::DisabilityCompensationForm::ServiceException)
            .and not_change(backup_klass.jobs, :size)
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:retryable_error]
        end
      end
    end

    context 'with a pif in use server error' do
      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_pif_in_use') do
          subject.perform_async(submission.id)
          expect_any_instance_of(Sidekiq::Form526JobStatusTracker::Metrics).to receive(:increment_non_retryable).once
          expect { described_class.drain }.to change(backup_klass.jobs, :size).by(1)
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
          expect(backup_klass.jobs.last['class']).to eq(backup_klass.to_s)
        end
      end
    end

    context 'with a VeteranRecordWsClientException java error' do
      it 'sets the transaction to "retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_java_ws_error') do
          subject.perform_async(submission.id)
          expect_any_instance_of(Sidekiq::Form526JobStatusTracker::Metrics).to receive(:increment_retryable).once
          expect { described_class.drain }.to raise_error(EVSS::DisabilityCompensationForm::ServiceException)
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:retryable_error]
        end
      end
    end

    context 'with an error that is not mapped' do
      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_unmapped') do
          subject.perform_async(submission.id)
          expect { described_class.drain }.to change(backup_klass.jobs, :size).by(1)
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
        end
      end
    end

    context 'with an unexpected error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
      end

      it 'sets the transaction to "non_retryable_error"' do
        subject.perform_async(submission.id)
        expect { described_class.drain }.to change(backup_klass.jobs, :size).by(1)
        expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
      end
    end

    context 'with an RRD claim' do
      context 'with a non-retryable (unexpected) error' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
        end

        it 'sends a "non-retryable" RRD alert' do
          subject.perform_async(submission.id)
          described_class.drain
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
        end
      end
    end
  end
end
