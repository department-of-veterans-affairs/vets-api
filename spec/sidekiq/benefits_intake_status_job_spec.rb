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
      it 'logs the error' do
        create_list(:form_submission, 2, :pending)
        message = 'error'
        response = double(body: message, success?: false)
        service = double(bulk_status: response)

        allow(BenefitsIntake::Service).to receive(:new).and_return(service)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)

        BenefitsIntakeStatusJob.new.perform

        expect(Rails.logger).to have_received(:error).with('Error processing Intake Status batch',
                                                           class: 'BenefitsIntakeStatusJob', message:)
        expect(Rails.logger).not_to have_received(:info).with('BenefitsIntakeStatusJob ended')
      end
    end

    describe 'updating the form submission status' do
      before { allow_any_instance_of(SimpleFormsApi::NotificationEmail).to receive(:send) }

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

    describe 'updating the Burial form submission status' do
      before do
        Flipper.enable(:burial_received_email_notification)
      end

      it 'updates the burial status with vbms from the bulk status report endpoint' do
        claim = build(:burial_claim)
        pending_form_submission_attempts = create_list(:form_submission_attempt, 1, :pending)
        batch_uuids = pending_form_submission_attempts.map(&:benefits_intake_uuid)
        data = batch_uuids.map { |id| { 'id' => id, 'attributes' => { 'status' => 'vbms' } } }
        response = double(success?: true, body: { 'data' => data })

        status_job = BenefitsIntakeStatusJob.new

        claim.update!(id: rand(100..1000))
        pfsa = pending_form_submission_attempts.first
        pfsa.form_submission.update!(form_type: claim.form_id, saved_claim_id: claim.id)

        expect(status_job).to receive(:log_result).with('success', pfsa.form_submission.form_type,
                                                        pfsa.benefits_intake_uuid, anything)
        expect_any_instance_of(Burials::NotificationEmail).to receive(:deliver).with(:received)
        expect_any_instance_of(BenefitsIntake::Service).to receive(:bulk_status)
          .with(uuids: batch_uuids).and_return(response)

        status_job.perform

        pending_form_submission_attempts.each do |form_submission_attempt|
          expect(form_submission_attempt.reload.aasm_state).to eq 'vbms'
        end
      end
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

  # end RSpec.describe
end
