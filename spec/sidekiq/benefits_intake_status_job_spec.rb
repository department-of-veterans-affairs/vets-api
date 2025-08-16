# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BenefitsIntakeStatusJob, type: :job do
  describe '#perform' do
    describe 'submission to the bulk status report endpoint' do
      context 'multiple attempts and multiple form submissions' do
        before do
          create_list(:form_submission, 2, :success)
          create_list(:form_submission, 2, :failure)
        end

        let(:pending_form_submission_attempts_ids) do
          create_list(:form_submission_attempt, 2,
                      :pending).map(&:benefits_intake_uuid)
        end

        it 'submits only pending form submissions' do
          response = double(body: { 'data' => [] }, success?: true)

          expect_any_instance_of(BenefitsIntake::Service).to receive(:bulk_status)
            .with(uuids: pending_form_submission_attempts_ids).and_return(response)

          BenefitsIntakeStatusJob.new.perform
        end
      end

      context 'multiple attempts on one form submission' do
        before do
          create(:form_submission_attempt, :success, form_submission:)
        end

        let(:form_submission) { create(:form_submission) }
        let(:pending_form_submission_attempts_ids) do
          create_list(:form_submission_attempt, 2,
                      :pending, form_submission:).map(&:benefits_intake_uuid)
        end

        it 'submits only pending form submissions' do
          response = double(body: { 'data' => [] }, success?: true)

          expect_any_instance_of(BenefitsIntake::Service).to receive(:bulk_status)
            .with(uuids: pending_form_submission_attempts_ids).and_return(response)

          BenefitsIntakeStatusJob.new.perform
        end
      end
    end

    describe 'when batch size is less than or equal to max batch size' do
      it 'successfully submits batch intake' do
        pending_form_submission_attempts_ids = create_list(:form_submission_attempt, 2,
                                                           :pending).map(&:benefits_intake_uuid)
        response = double(body: { 'data' => [] }, success?: true)

        expect_any_instance_of(BenefitsIntake::Service).to receive(:bulk_status)
          .with(uuids: pending_form_submission_attempts_ids).and_return(response)

        BenefitsIntakeStatusJob.new.perform
      end
    end

    describe 'when batch size is greater than max batch size' do
      it 'successfully submits batch intake via batch' do
        create_list(:form_submission, 4, :pending)
        response = double(body: { 'data' => [] }, success?: true)
        service = double(bulk_status: response)

        allow(BenefitsIntake::Service).to receive(:new).and_return(service)

        BenefitsIntakeStatusJob.new(batch_size: 2).perform

        expect(service).to have_received(:bulk_status).twice
      end
    end

    describe 'when bulk status update fails' do
      let(:service) { instance_double(BenefitsIntake::Service) }
      let(:form_submissions) { create_list(:form_submission, 4, :pending) }
      let(:success_response) { double(body: success_body, success?: true) }
      let(:failure_response) { double(body: failure_body, success?: false) }
      let(:success_body) do
        { 'data' =>
          [{
            'id' => form_submissions.first.form_submission_attempts.first.benefits_intake_uuid,
            'type' => 'document_upload',
            'attributes' => {
              'guid' => form_submissions.first.form_submission_attempts.first.benefits_intake_uuid,
              'status' => 'pending',
              'code' => 'DOC108',
              'detail' => 'Maximum page size exceeded. Limit is 78 in x 101 in.',
              'updated_at' => '2018-07-30T17:31:15.958Z',
              'created_at' => '2018-07-30T17:31:15.958Z'
            }
          }] }
      end
      let(:failure_body) { 'error' }

      before do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
        allow_any_instance_of(SimpleFormsApi::Notification::Email).to receive(:send)

        allow(BenefitsIntake::Service).to receive(:new).and_return(service)
        allow(service).to(
          receive(:bulk_status).and_return(success_response, success_response, failure_response, success_response)
        )

        described_class.new(batch_size: 1).perform
      end

      it 'logs the error' do
        expect(Rails.logger).to have_received(:error).with('Errors occurred while processing Intake Status batch',
                                                           class: 'BenefitsIntakeStatusJob', errors: [failure_body])
        expect(Rails.logger).not_to have_received(:info).with('BenefitsIntakeStatusJob ended')
      end

      it 'does not short circuit the batch processing job' do
        expect(service).to have_received(:bulk_status).exactly(4).times
      end
    end

    describe 'updating the form submission status' do
      before { allow_any_instance_of(SimpleFormsApi::Notification::Email).to receive(:send) }

      it 'updates the status with vbms from the bulk status report endpoint' do
        pending_form_submission_attempts = create_list(:form_submission_attempt, 1, :pending)
        batch_uuids = pending_form_submission_attempts.map(&:benefits_intake_uuid)
        data = batch_uuids.map { |id| { 'id' => id, 'attributes' => { 'status' => 'vbms' } } }
        response = double(success?: true, body: { 'data' => data })

        status_job = BenefitsIntakeStatusJob.new

        pfsa = pending_form_submission_attempts.first
        expect(status_job).to receive(:log_result).with('success', pfsa.form_submission.form_type,
                                                        pfsa.benefits_intake_uuid, anything)
        expect_any_instance_of(BenefitsIntake::Service).to receive(:bulk_status)
          .with(uuids: batch_uuids).and_return(response)

        status_job.perform

        pending_form_submission_attempts.each do |form_submission_attempt|
          expect(form_submission_attempt.reload.aasm_state).to eq 'vbms'
        end
      end

      it 'updates the status with error from the bulk status report endpoint' do
        pending_form_submission_attempts = create_list(:form_submission_attempt, 1, :pending)
        batch_uuids = pending_form_submission_attempts.map(&:benefits_intake_uuid)
        error_code = 'error-code'
        error_detail = 'error-detail'
        data = batch_uuids.map do |id|
          { 'id' => id, 'attributes' => { 'code' => error_code, 'detail' => error_detail, 'status' => 'error' } }
        end
        response = double(success?: true, body: { 'data' => data })

        status_job = BenefitsIntakeStatusJob.new

        pfsa = pending_form_submission_attempts.first
        expect(status_job).to receive(:log_result).with('failure', pfsa.form_submission.form_type,
                                                        pfsa.benefits_intake_uuid, anything,
                                                        "#{error_code}: #{error_detail}")
        expect_any_instance_of(BenefitsIntake::Service).to receive(:bulk_status)
          .with(uuids: batch_uuids).and_return(response)

        status_job.perform

        pending_form_submission_attempts.each do |form_submission_attempt|
          expect(form_submission_attempt.reload.aasm_state).to eq 'failure'
        end
      end

      it 'updates the status with expired from the bulk status report endpoint' do
        pending_form_submission_attempts = create_list(:form_submission_attempt, 1, :pending)
        batch_uuids = pending_form_submission_attempts.map(&:benefits_intake_uuid)
        data = batch_uuids.map { |id| { 'id' => id, 'attributes' => { 'status' => 'expired' } } }
        response = double(success?: true, body: { 'data' => data })

        status_job = BenefitsIntakeStatusJob.new

        pfsa = pending_form_submission_attempts.first
        expect(status_job).to receive(:log_result).with('failure', pfsa.form_submission.form_type,
                                                        pfsa.benefits_intake_uuid, anything,
                                                        'expired')
        expect_any_instance_of(BenefitsIntake::Service).to receive(:bulk_status)
          .with(uuids: batch_uuids).and_return(response)

        status_job.perform

        pending_form_submission_attempts.each do |form_submission_attempt|
          expect(form_submission_attempt.reload.aasm_state).to eq 'failure'
        end
      end

      it 'logs a stale submission if over the number of SLA days' do
        pending_form_submission_attempts = create_list(:form_submission_attempt, 1, :stale)
        batch_uuids = pending_form_submission_attempts.map(&:benefits_intake_uuid)
        data = batch_uuids.map { |id| { 'id' => id, 'attributes' => { 'status' => 'ANYTHING-ELSE' } } }
        response = double(success?: true, body: { 'data' => data })

        status_job = BenefitsIntakeStatusJob.new

        pfsa = pending_form_submission_attempts.first
        expect(status_job).to receive(:log_result).with('stale', pfsa.form_submission.form_type,
                                                        pfsa.benefits_intake_uuid, anything)
        expect_any_instance_of(BenefitsIntake::Service).to receive(:bulk_status)
          .with(uuids: batch_uuids).and_return(response)

        status_job.perform

        pending_form_submission_attempts.each do |form_submission_attempt|
          expect(form_submission_attempt.reload.aasm_state).to eq 'pending'
        end
      end

      it 'logs a pending submission' do
        pending_form_submission_attempts = create_list(:form_submission_attempt, 1, :pending)
        batch_uuids = pending_form_submission_attempts.map(&:benefits_intake_uuid)
        data = batch_uuids.map { |id| { 'id' => id, 'attributes' => { 'status' => 'ANYTHING-ELSE' } } }
        response = double(success?: true, body: { 'data' => data })

        status_job = BenefitsIntakeStatusJob.new

        pfsa = pending_form_submission_attempts.first
        expect(status_job).to receive(:log_result).with('pending', pfsa.form_submission.form_type,
                                                        pfsa.benefits_intake_uuid)
        expect_any_instance_of(BenefitsIntake::Service).to receive(:bulk_status)
          .with(uuids: batch_uuids).and_return(response)

        status_job.perform

        pending_form_submission_attempts.each do |form_submission_attempt|
          expect(form_submission_attempt.reload.aasm_state).to eq 'pending'
        end
      end

      # end 'updating the form submission status'
    end

    # end #perform
  end

  describe '#log_result' do
    it 'increments StatsD and logs result' do
      expect(StatsD).to receive(:increment).with("#{described_class::STATS_KEY}.FORM_ID.RESULT")
      expect(StatsD).to receive(:increment).with("#{described_class::STATS_KEY}.all_forms.RESULT")
      expect(Rails.logger).to receive(:info).with('BenefitsIntakeStatusJob',
                                                  hash_including(result: 'RESULT', form_id: 'FORM_ID', uuid: 'UUID',
                                                                 time_to_transition: nil))

      BenefitsIntakeStatusJob.new.send(:log_result, 'RESULT', 'FORM_ID', 'UUID')
    end
  end

  describe '#monitor_failure with VFF forms' do
    let(:job) { BenefitsIntakeStatusJob.new }
    let(:vff_monitor) { instance_double(VFF::Monitor) }
    let(:saved_claim_id) { 12345 }
    let(:benefits_intake_uuid) { 'test-uuid-456' }

    before do
      allow(VFF::Monitor).to receive(:new).and_return(vff_monitor)
      allow(vff_monitor).to receive(:track_benefits_intake_failure)
    end

    describe 'VFF form detection' do
      VFF::Monitor::VFF_FORM_IDS.each do |form_id|
        it "detects #{form_id} as a VFF form" do
          form_submission = create(:form_submission, form_type: form_id)
          form_submission_attempt = create(:form_submission_attempt,
                                         form_submission: form_submission,
                                         benefits_intake_uuid: benefits_intake_uuid)

          expect(VFF::Monitor.vff_form?(form_id)).to be true
          expect(VFF::Monitor).to receive(:new)
          expect(vff_monitor).to receive(:track_benefits_intake_failure)

          job.send(:monitor_failure, form_id, saved_claim_id, benefits_intake_uuid)
        end
      end

      it 'does not trigger VFF monitoring for non-VFF forms' do
        non_vff_forms = ['686C-674', '28-8832', '28-1900', 'UNKNOWN-FORM']

        non_vff_forms.each do |form_id|
          expect(VFF::Monitor.vff_form?(form_id)).to be false
          expect(VFF::Monitor).not_to receive(:new)
          expect(vff_monitor).not_to receive(:track_benefits_intake_failure)

          job.send(:monitor_failure, form_id, saved_claim_id, benefits_intake_uuid)
        end
      end
    end

    describe 'FormSubmission lookup' do
      let(:form_id) { '21-0966' }

      context 'when FormSubmission exists' do
        it 'finds the FormSubmission by benefits_intake_uuid' do
          form_submission = create(:form_submission, form_type: form_id)
          form_submission_attempt = create(:form_submission_attempt,
                                         form_submission: form_submission,
                                         benefits_intake_uuid: benefits_intake_uuid)

          # Mock the exact query that should be executed
          expect(FormSubmission).to receive(:joins).with(:form_submission_attempts).and_call_original

          expected_context = {
            form_id: form_id,
            claim_id: saved_claim_id,
            benefits_intake_uuid: benefits_intake_uuid
          }

          expect(vff_monitor).to receive(:track_benefits_intake_failure).with(
            expected_context,
            form_submission: form_submission
          )

          job.send(:monitor_failure, form_id, saved_claim_id, benefits_intake_uuid)
        end
      end

      context 'when FormSubmission does not exist' do
        it 'calls monitor with nil form_submission' do
          expected_context = {
            form_id: form_id,
            claim_id: saved_claim_id,
            benefits_intake_uuid: benefits_intake_uuid
          }

          expect(vff_monitor).to receive(:track_benefits_intake_failure).with(
            expected_context,
            form_submission: nil
          )

          job.send(:monitor_failure, form_id, saved_claim_id, benefits_intake_uuid)
        end
      end
    end

    describe 'monitor instantiation and method calls' do
      let(:form_id) { '21-4142' }

      it 'creates new VFF::Monitor instance' do
        expect(VFF::Monitor).to receive(:new).and_return(vff_monitor)

        job.send(:monitor_failure, form_id, saved_claim_id, benefits_intake_uuid)
      end

      it 'calls track_benefits_intake_failure with correct context' do
        expected_context = {
          form_id: form_id,
          claim_id: saved_claim_id,
          benefits_intake_uuid: benefits_intake_uuid
        }

        expect(vff_monitor).to receive(:track_benefits_intake_failure).with(
          expected_context,
          form_submission: nil
        )

        job.send(:monitor_failure, form_id, saved_claim_id, benefits_intake_uuid)
      end
    end

    describe 'integration with existing monitoring' do
      before do
        # Mock existing monitors to ensure they still work
        allow(SavedClaim::DependencyClaim).to receive(:find).and_return(nil)
        allow(SavedClaim::EducationCareerCounselingClaim).to receive(:find).and_return(nil)
        allow(SavedClaim::VeteranReadinessEmploymentClaim).to receive(:find).and_return(nil)
        allow_any_instance_of(Dependents::Monitor).to receive(:log_silent_failure)
        allow_any_instance_of(PCPG::Monitor).to receive(:log_silent_failure)
        allow_any_instance_of(VRE::Monitor).to receive(:log_silent_failure)
      end

      it 'VFF monitoring does not interfere with Dependents monitoring' do
        dependents_monitor = instance_double(Dependents::Monitor)
        allow(Dependents::Monitor).to receive(:new).and_return(dependents_monitor)
        allow(dependents_monitor).to receive(:log_silent_failure)

        # Test Dependents form still works
        job.send(:monitor_failure, '686C-674', saved_claim_id, benefits_intake_uuid)

        # Test VFF form still works
        expect(VFF::Monitor).to receive(:new).and_return(vff_monitor)
        expect(vff_monitor).to receive(:track_benefits_intake_failure)
        
        job.send(:monitor_failure, '21-0966', saved_claim_id, benefits_intake_uuid)
      end

      it 'VFF monitoring does not interfere with PCPG monitoring' do
        pcpg_monitor = instance_double(PCPG::Monitor)
        allow(PCPG::Monitor).to receive(:new).and_return(pcpg_monitor)
        allow(pcpg_monitor).to receive(:log_silent_failure)

        # Test PCPG form still works
        job.send(:monitor_failure, '28-8832', saved_claim_id, benefits_intake_uuid)

        # Test VFF form still works
        expect(VFF::Monitor).to receive(:new).and_return(vff_monitor)
        expect(vff_monitor).to receive(:track_benefits_intake_failure)
        
        job.send(:monitor_failure, '21-4142', saved_claim_id, benefits_intake_uuid)
      end

      it 'VFF monitoring does not interfere with VRE monitoring' do
        vre_monitor = instance_double(VRE::Monitor)
        allow(VRE::Monitor).to receive(:new).and_return(vre_monitor)
        allow(vre_monitor).to receive(:log_silent_failure)

        # Test VRE form still works
        job.send(:monitor_failure, '28-1900', saved_claim_id, benefits_intake_uuid)

        # Test VFF form still works
        expect(VFF::Monitor).to receive(:new).and_return(vff_monitor)
        expect(vff_monitor).to receive(:track_benefits_intake_failure)
        
        job.send(:monitor_failure, '21-10210', saved_claim_id, benefits_intake_uuid)
      end
    end

    describe 'error handling' do
      let(:form_id) { '21-0966' }

      it 'handles VFF::Monitor instantiation errors gracefully' do
        allow(VFF::Monitor).to receive(:new).and_raise(StandardError, 'Monitor error')

        expect { job.send(:monitor_failure, form_id, saved_claim_id, benefits_intake_uuid) }
          .not_to raise_error
      end

      it 'handles track_benefits_intake_failure errors gracefully' do
        allow(vff_monitor).to receive(:track_benefits_intake_failure)
          .and_raise(StandardError, 'Tracking error')

        expect { job.send(:monitor_failure, form_id, saved_claim_id, benefits_intake_uuid) }
          .not_to raise_error
      end
    end

    describe 'database query optimization' do
      let(:form_id) { '21-0845' }

      it 'uses efficient database query for FormSubmission lookup' do
        # Test that we use joins instead of N+1 queries
        expect(FormSubmission).to receive(:joins).with(:form_submission_attempts).and_call_original
        
        # Should call find_by only once
        joined_relation = FormSubmission.joins(:form_submission_attempts)
        expect(joined_relation).to receive(:find_by)
          .with(form_submission_attempts: { benefits_intake_uuid: benefits_intake_uuid })
          .once
          .and_return(nil)

        job.send(:monitor_failure, form_id, saved_claim_id, benefits_intake_uuid)
      end
    end
  end

  # end RSpec.describe
end
