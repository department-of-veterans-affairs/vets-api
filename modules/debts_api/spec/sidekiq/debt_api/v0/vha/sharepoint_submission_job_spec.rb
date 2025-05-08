# frozen_string_literal: true

require 'rails_helper'

require 'sidekiq/testing'

RSpec.describe DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob, type: :worker do
  describe '#perform' do
    let(:form_submission) { create(:debts_api_form5655_submission) }

    before do
      allow(DebtsApi::V0::Form5655Submission).to receive(:find).and_return(form_submission)
      allow(Flipper).to receive(:enabled?).and_return(false)
    end

    context 'with retries exhausted' do
      let(:config) { described_class }
      let(:msg) do
        {
          'class' => 'YourJobClassName',
          'args' => [form_submission.id],
          'jid' => '12345abcde',
          'retry_count' => 5
        }
      end

      let(:standard_exception) do
        e = StandardError.new('abc-123')
        allow(e).to receive(:backtrace).and_return(%w[backtrace1 backtrace2])
        e
      end

      it 'increments the retries exhausted counter' do
        statsd_key = DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob::STATS_KEY

        ["#{statsd_key}.failure", "#{statsd_key}.retries_exhausted", 'api.fsr_submission.failure'].each do |key|
          expect(StatsD).to receive(:increment).with(key)
        end

        config.sidekiq_retries_exhausted_block.call(msg, standard_exception)
      end

      it 'logs error information' do
        expect(Rails.logger).to receive(:error).with(
          "Form5655Submission id: #{form_submission.id} failed", 'SharePoint Submission Failed: .'
        )
        expect(Rails.logger).to receive(:error).with(
          a_string_matching(
            /
              V0::Form5655::VHA::SharepointSubmissionJob\ retries\ exhausted:\n
              submission_id:\ #{form_submission.id}\n
              Exception:\ .*\n
              Backtrace:.*
            /x
          )
        )

        config.sidekiq_retries_exhausted_block.call(msg, standard_exception)
      end

      it 'puts the form status into error' do
        described_class.within_sidekiq_retries_exhausted_block(msg, standard_exception) do
          expect(form_submission).to receive(:register_failure)
        end
      end

      context 'with advisory lock' do
        let(:sharepoint_request) { instance_double(DebtManagementCenter::Sharepoint::Request) }

        before do
          allow(DebtManagementCenter::Sharepoint::Request).to receive(:new).and_return(sharepoint_request)
          allow(sharepoint_request).to receive(:upload)
        end

        it 'uses an advisory lock during processing' do
          expect(DebtsApi::V0::Form5655Submission).to receive(:with_advisory_lock)
            .with("sharepoint-#{form_submission.id}", timeout_seconds: 15)
            .and_yield

          subject.perform(form_submission.id)
        end

        it 'skips processing for already submitted forms' do
          allow(form_submission).to receive(:submitted?).and_return(true)

          expect(DebtsApi::V0::Form5655Submission).to receive(:with_advisory_lock)
            .with("sharepoint-#{form_submission.id}", timeout_seconds: 15)
            .and_yield

          expect(sharepoint_request).not_to receive(:upload)

          subject.perform(form_submission.id)
        end

        it 'logs SharePoint errors' do
          expect(Rails.logger).to receive(:error)
            .with('SharePoint submission failed: Something went wrong', { submission_id: form_submission.id })

          expect(DebtsApi::V0::Form5655Submission).to receive(:with_advisory_lock)
            .with("sharepoint-#{form_submission.id}", timeout_seconds: 15)
            .and_yield

          error = StandardError.new('Something went wrong')
          allow(sharepoint_request).to receive(:upload).and_raise(error)

          expect { subject.perform(form_submission.id) }.to raise_error(StandardError)
        end
      end
    end
  end
end
