# frozen_string_literal: true

require 'rails_helper'
require 'form_intake/service'
require 'form_intake/service_error'
require 'form_intake/mappers/registry'
require 'form_intake/mappers/base_mapper'
require 'form_intake/mappers/vba_21p_601_mapper'

RSpec.describe FormIntake::SubmitFormDataJob, type: :job do
  let(:form_submission) { create(:form_submission, form_type: '21P-601') }
  let(:benefits_intake_uuid) { SecureRandom.uuid }
  let(:job) { described_class.new }

  before do
    # rubocop:disable Naming/VariableNumber
    Flipper.enable(:form_intake_integration_601)
    # rubocop:enable Naming/VariableNumber
    allow(StatsD).to receive(:increment)
  end

  describe '#perform' do
    context 'successful submission' do
      let(:payload) { { 'FORM_TYPE' => 'StructuredData:21P-601', 'VETERAN_NAME' => 'Test' } }
      let(:response) do
        {
          status: 200,
          body: '{"data":{"id":"gcio-123"}}',
          submission_id: 'gcio-123',
          tracking_number: 'TRACK-456'
        }
      end

      before do
        allow_any_instance_of(FormIntake::Mappers::VBA21p601Mapper).to receive(:to_gcio_payload).and_return(payload)
        allow_any_instance_of(FormIntake::Service).to receive(:submit_form_data).and_return(response)
      end

      it 'creates FormIntakeSubmission record' do
        expect do
          job.perform(form_submission.id, benefits_intake_uuid)
        end.to change(FormIntakeSubmission, :count).by(1)
      end

      it 'updates submission with GCIO response' do
        job.perform(form_submission.id, benefits_intake_uuid)

        submission = FormIntakeSubmission.last
        expect(submission.form_intake_submission_id).to eq('gcio-123')
        expect(submission.gcio_tracking_number).to eq('TRACK-456')
        expect(submission.aasm_state).to eq('success')
      end

      it 'stores request payload' do
        job.perform(form_submission.id, benefits_intake_uuid)

        submission = FormIntakeSubmission.last
        expect(submission.request_payload).to include('StructuredData:21P-601')
      end

      it 'logs success' do
        allow(Rails.logger).to receive(:info) # Allow AASM logs
        expect(Rails.logger).to receive(:info).with(
          'GCIO submission succeeded',
          hash_including(
            form_submission_id: form_submission.id,
            gcio_submission_id: 'gcio-123'
          )
        )

        job.perform(form_submission.id, benefits_intake_uuid)
      end

      it 'increments success metric' do
        job.perform(form_submission.id, benefits_intake_uuid)

        expect(StatsD).to have_received(:increment).with(
          'worker.form_intake_mms.submit_form_data.success',
          hash_including(tags: array_including('form_type:21P-601'))
        )
      end
    end

    context 'when form not eligible' do
      before do
        # rubocop:disable Naming/VariableNumber
        Flipper.disable(:form_intake_integration_601)
        # rubocop:enable Naming/VariableNumber
      end

      it 'skips submission' do
        expect_any_instance_of(FormIntake::Service).not_to receive(:submit_form_data)
        job.perform(form_submission.id, benefits_intake_uuid)
      end

      it 'logs skip reason' do
        allow(Rails.logger).to receive(:info) # Allow job start log
        expect(Rails.logger).to receive(:info).with(
          'GCIO submission skipped: Form not eligible',
          hash_including(form_submission_id: form_submission.id)
        )

        job.perform(form_submission.id, benefits_intake_uuid)
      end

      it 'increments skipped metric' do
        job.perform(form_submission.id, benefits_intake_uuid)

        expect(StatsD).to have_received(:increment).with(
          'worker.form_intake_mms.submit_form_data.skipped',
          hash_including(tags: array_including('reason:form_not_eligible'))
        )
      end
    end

    context 'when no mapper found' do
      let(:unmapped_form) { create(:form_submission, form_type: 'UNMAPPED') }

      before do
        stub_const('FormIntake::ELIGIBLE_FORMS', ['UNMAPPED'])
        stub_const('FormIntake::FORM_FEATURE_FLAGS', { 'UNMAPPED' => :test_flag })
        Flipper.enable(:test_flag)
      end

      it 'skips submission' do
        expect_any_instance_of(FormIntake::Service).not_to receive(:submit_form_data)
        job.perform(unmapped_form.id, benefits_intake_uuid)
      end

      it 'logs skip reason' do
        expect(Rails.logger).to receive(:error).with(
          'Mapper not found',
          hash_including(form_type: 'UNMAPPED')
        )

        job.perform(unmapped_form.id, benefits_intake_uuid)
      end
    end

    context 'retryable error' do
      let(:retryable_error) { FormIntake::ServiceError.new('Timeout', 504) }

      before do
        allow_any_instance_of(FormIntake::Service).to receive(:submit_form_data).and_raise(retryable_error)
      end

      it 're-raises error for Sidekiq retry' do
        expect do
          job.perform(form_submission.id, benefits_intake_uuid)
        end.to raise_error(FormIntake::ServiceError)
      end

      it 'logs retryable error' do
        allow(Rails.logger).to receive(:info) # Allow job start log
        expect(Rails.logger).to receive(:warn).with(
          'GCIO submission retryable error - will retry',
          hash_including(
            form_submission_id: form_submission.id,
            status_code: 504,
            max_retries: 16
          )
        )

        expect { job.perform(form_submission.id, benefits_intake_uuid) }.to raise_error(FormIntake::ServiceError)
      end

      it 'increments retryable error metric' do
        expect { job.perform(form_submission.id, benefits_intake_uuid) }.to raise_error(FormIntake::ServiceError)

        expect(StatsD).to have_received(:increment).with(
          'worker.form_intake_mms.submit_form_data.retryable_error',
          hash_including(tags: array_including('status:504'))
        )
      end

      it 'does not mark as failed' do
        expect { job.perform(form_submission.id, benefits_intake_uuid) }.to raise_error(FormIntake::ServiceError)

        submission = FormIntakeSubmission.last
        expect(submission.aasm_state).not_to eq('failed')
      end
    end

    context 'non-retryable error' do
      let(:non_retryable_error) { FormIntake::ServiceError.new('Bad Request', 400) }

      before do
        allow_any_instance_of(FormIntake::Service).to receive(:submit_form_data).and_raise(non_retryable_error)
      end

      it 'does not re-raise error' do
        expect do
          job.perform(form_submission.id, benefits_intake_uuid)
        end.not_to raise_error
      end

      it 'marks submission as failed' do
        job.perform(form_submission.id, benefits_intake_uuid)

        submission = FormIntakeSubmission.last
        expect(submission.aasm_state).to eq('failed')
      end

      it 'logs non-retryable error' do
        allow(Rails.logger).to receive(:error)  # Allow AASM logs
        expect(Rails.logger).to receive(:error).with(
          'GCIO submission non-retryable error',
          hash_including(
            form_submission_id: form_submission.id,
            status_code: 400
          )
        )

        job.perform(form_submission.id, benefits_intake_uuid)
      end

      it 'increments non-retryable error metric' do
        job.perform(form_submission.id, benefits_intake_uuid)

        expect(StatsD).to have_received(:increment).with(
          'worker.form_intake_mms.submit_form_data.non_retryable_error',
          hash_including(tags: array_including('status:400'))
        )
      end
    end

    context 'unexpected error' do
      let(:unexpected_error) { StandardError.new('Something went wrong') }

      before do
        allow_any_instance_of(FormIntake::Mappers::VBA21p601Mapper).to receive(:to_gcio_payload)
          .and_raise(unexpected_error)
      end

      it 're-raises error for Sidekiq retry' do
        expect do
          job.perform(form_submission.id, benefits_intake_uuid)
        end.to raise_error(StandardError, 'Something went wrong')
      end

      it 'logs unexpected error' do
        expect(Rails.logger).to receive(:error).with(
          'GCIO submission unexpected error',
          hash_including(
            form_submission_id: form_submission.id,
            error_class: 'StandardError'
          )
        )

        expect { job.perform(form_submission.id, benefits_intake_uuid) }.to raise_error(StandardError)
      end

      it 'increments unexpected error metric' do
        expect { job.perform(form_submission.id, benefits_intake_uuid) }.to raise_error(StandardError)

        expect(StatsD).to have_received(:increment).with(
          'worker.form_intake_mms.submit_form_data.unexpected_error',
          hash_including(tags: array_including('error_class:StandardError'))
        )
      end
    end

    context 'retry count tracking' do
      let(:existing_submission) do
        create(:form_intake_submission,
               form_submission:,
               benefits_intake_uuid:,
               retry_count: 2,
               aasm_state: 'pending')
      end
      let(:retryable_error) { FormIntake::ServiceError.new('Timeout', 504) }

      before do
        existing_submission
        allow_any_instance_of(FormIntake::Service).to receive(:submit_form_data).and_raise(retryable_error)
      end

      it 'increments retry count on retry' do
        expect do
          job.perform(form_submission.id, benefits_intake_uuid)
        end.to raise_error(FormIntake::ServiceError)

        existing_submission.reload
        expect(existing_submission.retry_count).to eq(3)
      end

      it 'updates last_attempted_at' do
        expect do
          job.perform(form_submission.id, benefits_intake_uuid)
        end.to raise_error(FormIntake::ServiceError)

        existing_submission.reload
        expect(existing_submission.last_attempted_at).to be_present
        expect(existing_submission.last_attempted_at).to be_within(1.second).of(Time.current)
      end
    end

    describe '.handle_exhaustion' do
      let!(:form_intake_submission) do
        create(:form_intake_submission, form_submission:, aasm_state: 'pending')
      end

      it 'marks submission as failed' do
        described_class.handle_exhaustion(form_submission.id, 'Max retries exceeded')

        form_intake_submission.reload
        expect(form_intake_submission.aasm_state).to eq('failed')
      end

      it 'logs exhaustion' do
        allow(Rails.logger).to receive(:error)  # Allow AASM logs
        expect(Rails.logger).to receive(:error).with(
          'GCIO submission retries exhausted',
          hash_including(
            form_submission_id: form_submission.id,
            form_intake_submission_id: form_intake_submission.id
          )
        )

        described_class.handle_exhaustion(form_submission.id, 'Max retries exceeded')
      end

      it 'increments exhausted metric' do
        described_class.handle_exhaustion(form_submission.id, 'Max retries exceeded')

        expect(StatsD).to have_received(:increment).with(
          'worker.form_intake_mms.submit_form_data.exhausted'
        )
      end
    end

    describe 'DataDog tracing' do
      let(:span) { instance_double(Datadog::Tracing::Span) }
      let(:payload) { { 'FORM_TYPE' => 'StructuredData:21P-601' } }
      let(:response) { { status: 200, body: '{}', submission_id: 'test', tracking_number: 'track' } }

      before do
        allow(Datadog::Tracing).to receive(:trace).and_yield(span)
        allow(span).to receive(:set_tag)
        allow_any_instance_of(FormIntake::Mappers::VBA21p601Mapper).to receive(:to_gcio_payload).and_return(payload)
        allow_any_instance_of(FormIntake::Service).to receive(:submit_form_data).and_return(response)
      end

      it 'creates trace span' do
        job.perform(form_submission.id, benefits_intake_uuid)

        expect(Datadog::Tracing).to have_received(:trace).with('form_intake.submit_form_data_job')
      end

      it 'sets trace tags' do
        job.perform(form_submission.id, benefits_intake_uuid)

        expect(span).to have_received(:set_tag).with('form_submission_id', form_submission.id)
        expect(span).to have_received(:set_tag).with('form_type', '21P-601')
        expect(span).to have_received(:set_tag).with('benefits_intake_uuid', benefits_intake_uuid)
      end
    end
  end
end
