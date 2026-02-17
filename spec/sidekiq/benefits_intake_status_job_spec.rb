# frozen_string_literal: true

require 'rails_helper'
require 'vre/notification_email'

RSpec.describe BenefitsIntakeStatusJob, type: :job do
  describe '#perform' do
    describe 'job lifecycle metrics' do
      it 'increments job.started and job.completed when job begins and finishes' do
        allow_any_instance_of(BenefitsIntake::Service).to receive(:bulk_status)
          .and_return(double(body: { 'data' => [] }, success?: true))

        expect(StatsD).to receive(:increment)
          .with("#{described_class::STATS_KEY}.job.started")
        expect(StatsD).to receive(:increment)
          .with("#{described_class::STATS_KEY}.job.completed")

        BenefitsIntakeStatusJob.new.perform
      end

      it 'increments job.failed when batch_process returns false' do
        allow_any_instance_of(described_class).to receive(:batch_process).and_return([0, false])

        expect(StatsD).to receive(:increment)
          .with("#{described_class::STATS_KEY}.job.started")
        expect(StatsD).to receive(:increment)
          .with("#{described_class::STATS_KEY}.job.failed")

        BenefitsIntakeStatusJob.new.perform
      end

      it 'increments job.failed and re-raises exception on unexpected errors' do
        allow(FormSubmissionAttempt).to receive(:where).and_raise(StandardError.new('Database error'))

        expect(StatsD).to receive(:increment)
          .with("#{described_class::STATS_KEY}.job.started")
        expect(StatsD).to receive(:increment)
          .with("#{described_class::STATS_KEY}.job.failed")
        expect(Rails.logger).to receive(:error)
          .with('BenefitsIntakeStatusJob failed with exception',
                hash_including(class: 'BenefitsIntakeStatusJob', message: 'Database error'))

        expect { BenefitsIntakeStatusJob.new.perform }.to raise_error(StandardError, 'Database error')
      end
    end

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

  describe '#monitor_failure' do
    let(:benefits_intake_uuid) { SecureRandom.uuid }

    context 'when form is VRE 28-1900' do
      let(:form_id) { '28-1900' }
      let(:claim) { create(:veteran_readiness_employment_claim) }

      context 'when claim and email are present' do
        it 'sends error email via VRE::NotificationEmail and logs silent failure avoided' do
          expect_any_instance_of(VRE::NotificationEmail).to receive(:deliver).with(:error)

          monitor = instance_double(VRE::VREMonitor)
          allow(VRE::VREMonitor).to receive(:new).and_return(monitor)
          expect(monitor).to receive(:log_silent_failure_avoided)

          BenefitsIntakeStatusJob.new.send(:monitor_failure, form_id, claim.id, benefits_intake_uuid)
        end
      end

      context 'when claim is present but email is blank' do
        let(:claim) do
          create(:veteran_readiness_employment_claim).tap do |c|
            form = JSON.parse(c.form)
            form['email'] = ''
            c.update(form: form.to_json)
          end
        end

        it 'logs silent failure without sending email' do
          monitor = instance_double(VRE::VREMonitor)
          allow(VRE::VREMonitor).to receive(:new).and_return(monitor)
          expect(monitor).to receive(:log_silent_failure)

          BenefitsIntakeStatusJob.new.send(:monitor_failure, form_id, claim.id, benefits_intake_uuid)
        end
      end
    end

    context 'when form is PCPG 28-8832' do
      let(:form_id) { '28-8832' }
      let(:claim) { create(:education_career_counseling_claim) }

      context 'when claim and email are present' do
        it 'sends failure email via VANotify and logs silent failure no confirmation' do
          expect(VANotify::EmailJob).to receive(:perform_async)

          monitor = instance_double(PCPG::Monitor)
          allow(PCPG::Monitor).to receive(:new).and_return(monitor)
          expect(monitor).to receive(:log_silent_failure_no_confirmation)

          BenefitsIntakeStatusJob.new.send(:monitor_failure, form_id, claim.id, benefits_intake_uuid)
        end
      end

      context 'when email is missing' do
        let(:claim) do
          create(:education_career_counseling_claim).tap do |c|
            form = JSON.parse(c.form)
            form['claimantInformation']['emailAddress'] = nil
            c.update(form: form.to_json)
          end
        end

        it 'logs silent failure without sending email' do
          monitor = instance_double(PCPG::Monitor)
          allow(PCPG::Monitor).to receive(:new).and_return(monitor)
          expect(monitor).to receive(:log_silent_failure)

          BenefitsIntakeStatusJob.new.send(:monitor_failure, form_id, claim.id, benefits_intake_uuid)
        end
      end
    end

    context 'when form is Dependents 686C-674' do
      let(:form_id) { '686C-674' }
      let(:claim) { create(:dependency_claim) }

      context 'when claim and email are present' do
        it 'sends failure email via Sidekiq job and logs silent failure no confirmation' do
          expect(Dependents::Form686c674FailureEmailJob).to receive(:perform_async)

          # The monitor method is called on the claim, so we need to stub it before the method runs
          allow_any_instance_of(Dependents::Monitor).to receive(:log_silent_failure_no_confirmation)

          BenefitsIntakeStatusJob.new.send(:monitor_failure, form_id, claim.id, benefits_intake_uuid)
        end
      end

      context 'when email is missing' do
        let(:claim) { create(:dependency_claim) }

        before do
          form = JSON.parse(claim.form)
          form['dependents_application']['veteran_contact_information']['email_address'] = nil
          claim.update(form: form.to_json)
        end

        it 'logs silent failure without sending email' do
          monitor = instance_double(Dependents::Monitor)
          allow(Dependents::Monitor).to receive(:new).and_return(monitor)
          expect(monitor).to receive(:log_silent_failure)

          BenefitsIntakeStatusJob.new.send(:monitor_failure, form_id, claim.id, benefits_intake_uuid)
        end
      end
    end
  end

  # end RSpec.describe
end
