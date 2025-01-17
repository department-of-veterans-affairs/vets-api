# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_intake/sidekiq/submission_status_job'

Rspec.describe BenefitsIntake::SubmissionStatusJob, type: :job do
  let(:job) { described_class.new }
  let(:stats_key) { BenefitsIntake::SubmissionStatusJob::STATS_KEY }

  context 'flipper is disabled' do
    before do
      Flipper.disable(:benefits_intake_submission_status_job)
    end

    it 'does nothing' do
      expect(Rails.logger).not_to receive(:info)
      expect(Rails.logger).not_to receive(:error)
      expect(FormSubmissionAttempt).not_to receive(:where)
      expect(BenefitsIntake::Service).not_to receive(:new)
      job.perform
    end
  end

  context 'flipper is enabled' do
    let(:service) { BenefitsIntake::Service.new }
    let(:updated_at) { Time.zone.now }

    before do
      Flipper.enable(:benefits_intake_submission_status_job)

      allow(BenefitsIntake::Service).to receive(:new).and_return(service)

      create_list(:form_submission, 2, :success)
      create_list(:form_submission, 2, :failure)
      create_list(:form_submission, 4, :pending)
    end

    context 'submitting to status endpoint' do
      context 'failed status check' do
        it 'raises the response body' do
          failed = double(body: 'TEST FAILED CHECK', success?: false)
          expect(service).to receive(:bulk_status).and_return(failed)

          message = "#{job.class}: ERROR"
          payload = { class: job.class.to_s, message: 'TEST FAILED CHECK' }
          expect(Rails.logger).to receive(:error).with(message, **payload)

          job.perform
        end
      end

      it 'submits only pending form submissions' do
        fsa_pending_uuids = FormSubmissionAttempt.where(aasm_state: 'pending').map(&:benefits_intake_uuid)
        response = double(body: { 'data' => [] }, success?: true)
        expect(service).to receive(:bulk_status).with(uuids: fsa_pending_uuids).and_return(response)

        # returning an empty response so no further processing
        expect(StatsD).not_to receive(:increment)

        job.perform
      end

      context 'batch size is greater than max batch size' do
        it 'successfully submits batch intake via batch' do
          response = double(body: { 'data' => [] }, success?: true)
          service = double(bulk_status: response)

          expect(BenefitsIntake::Service).to receive(:new).and_return(service)
          expect(service).to receive(:bulk_status).twice

          # returning an empty response so no further processing
          expect(StatsD).not_to receive(:increment)

          BenefitsIntake::SubmissionStatusJob.new(batch_size: 2).perform
        end
      end
    end

    context 'processes status response' do
      let(:pending) { FormSubmissionAttempt.find_by(aasm_state: 'pending') }
      let(:form_id) { pending.form_submission.form_type }

      before do
        allow_any_instance_of(SimpleFormsApi::NotificationEmail).to receive(:send)
      end

      it 'skips non present uuid' do
        data = [{ 'id' => 'INVALID-UUID' }]
        response = double(body: { 'data' => data }, success?: true)
        expect(service).to receive(:bulk_status).and_return(response)

        expect(job).not_to receive(:update_attempt_record)
        expect(job).not_to receive(:monitor_attempt_status)
        expect(job).not_to receive(:handle_attempt_result)

        job.perform
      end

      def mock_response(status)
        attributes = {
          'status' => status.to_s,
          'updated_at' => updated_at,
          # below used in job when status == error
          'code' => 'CODE###',
          'detail' => 'TEST ERROR'
        }
        data = [{ 'id' => pending.benefits_intake_uuid, 'attributes' => attributes }]

        double(body: { 'data' => data }, success?: true)
      end

      it 'handles expired status' do
        expect(service).to receive(:bulk_status).and_return(mock_response(:expired))

        expect(StatsD).to receive(:increment).with("#{stats_key}.#{form_id}.failure").once
        expect(StatsD).to receive(:increment).with("#{stats_key}.all_forms.failure").once

        expect(job).to receive(:handle_attempt_result).once.with(pending.benefits_intake_uuid, 'expired')

        job.perform

        updated = pending.reload
        expect(updated.aasm_state).to eq 'failure'
        expect(updated.lighthouse_updated_at).to eq updated_at
        expect(updated.error_message).to eq 'expired'
      end

      it 'handles error status' do
        expect(service).to receive(:bulk_status).and_return(mock_response(:error))

        expect(StatsD).to receive(:increment).with("#{stats_key}.#{form_id}.failure").once
        expect(StatsD).to receive(:increment).with("#{stats_key}.all_forms.failure").once

        expect(job).to receive(:handle_attempt_result).once.with(pending.benefits_intake_uuid, 'error')

        job.perform

        updated = pending.reload
        expect(updated.aasm_state).to eq 'failure'
        expect(updated.lighthouse_updated_at).to eq updated_at
        expect(updated.error_message).to eq 'CODE###: TEST ERROR'
      end

      it 'handles vbms status' do
        expect(service).to receive(:bulk_status).and_return(mock_response(:vbms))

        expect(StatsD).to receive(:increment).with("#{stats_key}.#{form_id}.success").once
        expect(StatsD).to receive(:increment).with("#{stats_key}.all_forms.success").once

        expect(job).to receive(:handle_attempt_result).once.with(pending.benefits_intake_uuid, 'vbms')

        job.perform

        updated = pending.reload
        expect(updated.aasm_state).to eq 'vbms'
        expect(updated.lighthouse_updated_at).to eq updated_at
        expect(updated.error_message).to eq nil
      end

      it 'handles any other status' do
        expect(service).to receive(:bulk_status).and_return(mock_response(:any_other_status))

        expect(StatsD).to receive(:increment).with("#{stats_key}.#{form_id}.pending").once
        expect(StatsD).to receive(:increment).with("#{stats_key}.all_forms.pending").once

        expect(job).to receive(:handle_attempt_result).once.with(pending.benefits_intake_uuid, 'any_other_status')

        job.perform

        updated = pending.reload
        expect(updated.aasm_state).to eq 'pending'
        expect(updated.lighthouse_updated_at).to eq updated_at
        expect(updated.error_message).to eq nil
      end

      it 'handles a stale attempt' do
        expect(service).to receive(:bulk_status).and_return(mock_response(:any_other_status))

        allow_any_instance_of(FormSubmissionAttempt).to receive(:created_at).and_return(Time.zone.now - 99.days)
        expect(StatsD).to receive(:increment).with("#{stats_key}.#{form_id}.stale").once
        expect(StatsD).to receive(:increment).with("#{stats_key}.all_forms.stale").once

        expect(job).to receive(:handle_attempt_result).once.with(pending.benefits_intake_uuid, 'any_other_status')

        job.perform

        updated = pending.reload
        expect(updated.aasm_state).to eq 'pending'
        expect(updated.lighthouse_updated_at).to eq updated_at
        expect(updated.error_message).to eq nil
      end
    end

    # end for context flipper is enabled
  end
end
