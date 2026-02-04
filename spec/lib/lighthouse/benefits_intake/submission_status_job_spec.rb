# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_intake/sidekiq/submission_status_job'

RSpec.describe BenefitsIntake::SubmissionStatusJob, type: :job do
  let(:job) { described_class.new }
  let(:stats_key) { described_class::STATS_KEY }

  context 'flipper is disabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(anything).and_call_original
      allow(Flipper).to receive(:enabled?).with(:benefits_intake_submission_status_job).and_return false
    end

    it 'does nothing' do
      expect(Rails.logger).not_to receive(:info)
      expect(Rails.logger).not_to receive(:error)
      expect(Lighthouse::SubmissionAttempt).not_to receive(:where)
      expect(BenefitsIntake::Service).not_to receive(:new)
      job.perform
    end
  end

  context 'flipper is enabled' do
    let(:service) { BenefitsIntake::Service.new }

    before do
      allow(Flipper).to receive(:enabled?).with(anything).and_call_original
      allow(Flipper).to receive(:enabled?).with(:benefits_intake_submission_status_job).and_return true
      allow(BenefitsIntake::Service).to receive(:new).and_return(service)
    end

    describe '.register_handler' do
      it 'registers a handler for a form_id' do
        dummy_handler = Class.new
        described_class.register_handler('FORM123', dummy_handler)
        expect(described_class::FORM_HANDLERS['FORM123']).to eq(dummy_handler)
      end
    end

    it 'processes only form_ids with handlers' do
      stub_const('BenefitsIntake::SubmissionStatusJob::FORM_HANDLERS', { 'FOO' => 'BAR' })
      expect(service).not_to receive(:bulk_status)

      # only the started, processing, and end log
      expect(Rails.logger).to receive(:info).thrice

      job.perform
    end

    describe '#log' do
      it 'logs info with correct format' do
        monitor = instance_double(Logging::Monitor)
        allow(Logging::Monitor).to receive(:new).with('benefits_intake_submission_status_job').and_return(monitor)
        expect(monitor).to receive(:track_request).with(:info, 'BenefitsIntake::SubmissionStatusJob: test message',
                                                        described_class::STATS_KEY, foo: 'bar')
        job.send(:log, :info, 'test message', foo: 'bar')
      end
    end

    describe '#pending_submission_attempts' do
      let(:handler) { double('Handler', pending_attempts: create_list(:lighthouse_submission_attempt, 1)) }

      before do
        stub_const('BenefitsIntake::SubmissionStatusJob::FORM_HANDLERS', { 'FORM1' => handler })
        allow(Rails.logger).to receive(:info)
      end

      it 'returns attempts for all handlers if form_id is nil' do
        expect(job.send(:pending_submission_attempts, nil).size).to eq(1)
      end

      it 'returns attempts for a specific form_id' do
        expect(job.send(:pending_submission_attempts, 'FORM1').size).to eq(1)
      end

      it 'returns empty if handler does not respond to pending_attempts' do
        stub_const('BenefitsIntake::SubmissionStatusJob::FORM_HANDLERS', { 'FORM2' => double('NoHandler') })
        expect(job.send(:pending_submission_attempts, 'FORM2')).to eq([])
      end
    end

    describe '#pending_attempts_hash' do
      let(:attempt) { create(:lighthouse_submission_attempt, benefits_intake_uuid: 'uuid-1') }

      before do
        job.instance_variable_set(:@pending_attempts, [attempt])
      end

      it 'returns a hash mapping uuid to attempt' do
        expect(job.send(:pending_attempts_hash)).to eq({ 'uuid-1' => attempt })
      end
    end

    describe '#attempt_status_result_context' do
      let(:submission) { create(:lighthouse_submission, form_id: 'FORM1', saved_claim_id: 123) }
      let(:attempt) do
        create(:lighthouse_submission_attempt,
               benefits_intake_uuid: 'uuid-1',
               submission:,
               created_at: 2.days.ago,
               error_message: 'err')
      end

      before do
        job.instance_variable_set(:@pending_attempts, [attempt])
        job.instance_variable_set(:@pah, { 'uuid-1' => attempt })
        stub_const('BenefitsIntake::SubmissionStatusJob::STALE_SLA', 1)
        allow(Time.zone).to receive(:now).and_return(Time.zone.now)
      end

      it 'returns context with mapped result' do
        context = job.send(:attempt_status_result_context, 'uuid-1', 'vbms')
        expect(context[:form_id]).to eq('FORM1')
        expect(context[:saved_claim_id]).to eq(123)
        expect(context[:uuid]).to eq('uuid-1')
        expect(context[:status]).to eq('vbms')
        expect(context[:result]).to eq('success')
        expect(context[:error_message]).to eq('err')
      end

      it 'returns stale if queue_time exceeds SLA and result is pending' do
        allow(attempt).to receive(:created_at).and_return(10.days.ago)
        context = job.send(:attempt_status_result_context, 'uuid-1', 'pending')
        expect(context[:result]).to eq('stale')
      end
    end

    describe '#handle_response' do
      let(:attempt) do
        create(:lighthouse_submission_attempt, benefits_intake_uuid: 'uuid-1',
                                               submission: create(:lighthouse_submission,
                                                                  form_id: 'FORM1', saved_claim_id: 1))
      end

      before do
        job.instance_variable_set(:@pending_attempts, [attempt])
        job.instance_variable_set(:@pah, { 'uuid-1' => attempt })
        allow(job).to receive(:update_attempt_record)
        allow(job).to receive(:monitor_attempt_status)
        allow(job).to receive(:handle_attempt_result)
        allow(job).to receive(:log)
      end

      it 'processes each submission in response_data' do
        data = [{ 'id' => 'uuid-1', 'attributes' => { 'status' => 'vbms' } }]
        expect(job).to receive(:update_attempt_record).with('uuid-1', 'vbms', data.first)
        expect(job).to receive(:monitor_attempt_status).with('uuid-1', 'vbms')
        expect(job).to receive(:handle_attempt_result).with('uuid-1', 'vbms')
        job.send(:handle_response, data)
      end

      it 'skips if uuid not found in pending_attempts_hash' do
        data = [{ 'id' => 'not-found', 'attributes' => { 'status' => 'vbms' } }]
        expect(job).not_to receive(:update_attempt_record)
        job.send(:handle_response, data)
      end
    end

    describe '#update_attempt_record' do
      describe 'when submission_attempt is Lighthouse::SubmissionAttempt' do
        let(:submission) { create(:lighthouse_submission, form_id: 'FORM1', saved_claim_id: 1) }
        let(:attempt) { create(:lighthouse_submission_attempt, benefits_intake_uuid: 'uuid-1', submission:) }
        let(:handler_instance) { double('HandlerInstance') }
        let(:handler_class) { double('HandlerClass', new: handler_instance) }

        before do
          job.instance_variable_set(:@pending_attempts, [attempt])
          job.instance_variable_set(:@pah, { 'uuid-1' => attempt })
          stub_const('BenefitsIntake::SubmissionStatusJob::FORM_HANDLERS', { 'FORM1' => handler_class })
        end

        it 'calls update_attempt_record on the handler' do
          expect(handler_class).to receive(:new).with(1).and_return(handler_instance)
          expect(handler_instance).to receive(:update_attempt_record).with('vbms', { foo: 'bar' }, attempt)
          job.send(:update_attempt_record, 'uuid-1', 'vbms', { foo: 'bar' })
        end
      end

      describe 'when submission_attempt is FormSubmission' do
        before do
          # This removes: SHRINE WARNING: Error occurred when attempting to extract image dimensions:
          # #<FastImage::UnknownImageType: FastImage::UnknownImageType>
          allow(FastImage).to receive(:size).and_wrap_original do |original, file|
            if file.respond_to?(:path) && file.path.end_with?('.pdf')
              nil
            else
              original.call(file)
            end
          end
          job.instance_variable_set(:@pending_attempts, [attempt])
          job.instance_variable_set(:@pah, { 'uuid-1' => attempt })
          stub_const('BenefitsIntake::SubmissionStatusJob::FORM_HANDLERS', { 'Form23-42Fake' => handler_class })
        end

        let(:saved_claim) { create(:saved_claim_benefits_intake) }
        let(:form_submission) { create(:form_submission, saved_claim:, form_type: 'Form23-42Fake') }
        let(:attempt) { create(:form_submission_attempt, form_submission:, benefits_intake_uuid: 'uuid-1') }
        let(:handler_instance) { double('HandlerInstance') }
        let(:handler_class) { double('HandlerClass', new: handler_instance) }

        it 'calls update_attempt_record on the handler' do
          expect(handler_class).to receive(:new).with(form_submission.saved_claim_id).and_return(handler_instance)
          expect(handler_instance).to receive(:update_attempt_record).with('vbms', { foo: 'bar' }, attempt)
          job.send(:update_attempt_record, 'uuid-1', 'vbms', { foo: 'bar' })
        end
      end
    end

    describe '#monitor_attempt_status' do
      let(:context) do
        {
          form_id: 'FORM1',
          saved_claim_id: 1,
          uuid: 'uuid-1',
          status: 'vbms',
          result: 'success',
          queue_time: 10,
          error_message: nil
        }
      end

      before do
        allow(job).to receive(:attempt_status_result_context).and_return(context)
        allow(job).to receive(:log)
      end

      it 'increments StatsD metrics and logs info' do
        expect(StatsD).to receive(:increment).with("#{stats_key}.FORM1.success")
        expect(StatsD).to receive(:increment).with("#{stats_key}.all_forms.success")
        expect(job).to receive(:log).with(:info, /UUID: uuid-1/, hash_including(result: 'success'))
        job.send(:monitor_attempt_status, 'uuid-1', 'vbms')
      end

      it 'logs error if result is failure' do
        context[:result] = 'failure'
        expect(StatsD).to receive(:increment).with("#{stats_key}.FORM1.failure")
        expect(StatsD).to receive(:increment).with("#{stats_key}.all_forms.failure")
        expect(job).to receive(:log).with(:error, /UUID: uuid-1/, hash_including(result: 'failure'))
        job.send(:monitor_attempt_status, 'uuid-1', 'error')
      end
    end

    describe '#handle_attempt_result' do
      let(:context) do
        {
          form_id: 'FORM1',
          saved_claim_id: 1,
          uuid: 'uuid-1',
          status: 'vbms',
          result: 'success',
          queue_time: 10,
          error_message: nil
        }
      end
      let(:handler_instance) { double('HandlerInstance') }
      let(:handler_class) { double('HandlerClass', new: handler_instance) }

      before do
        allow(job).to receive(:attempt_status_result_context).and_return(context)
        stub_const('BenefitsIntake::SubmissionStatusJob::FORM_HANDLERS', { 'FORM1' => handler_class })
      end

      it 'calls handle on the handler' do
        expect(handler_class).to receive(:new).with(1).and_return(handler_instance)
        expect(handler_instance).to receive(:handle).with('success',
                                                          hash_including(:call_location, :form_id, :uuid, :result,
                                                                         :status, :queue_time, :error_message,
                                                                         :saved_claim_id))
        job.send(:handle_attempt_result, 'uuid-1', 'vbms')
      end

      it 'logs error if handler raises' do
        expect(handler_class).to receive(:new).with(1).and_return(handler_instance)
        expect(handler_instance).to receive(:handle).and_raise(StandardError, 'fail')
        expect(job).to receive(:log).with(:error, 'ERROR handling result', hash_including(message: 'fail'))
        job.send(:handle_attempt_result, 'uuid-1', 'vbms')
      end

      it 'does nothing if no handler for form_id' do
        stub_const('BenefitsIntake::SubmissionStatusJob::FORM_HANDLERS', {})
        expect { job.send(:handle_attempt_result, 'uuid-1', 'vbms') }.not_to raise_error
      end
    end
  end
end
