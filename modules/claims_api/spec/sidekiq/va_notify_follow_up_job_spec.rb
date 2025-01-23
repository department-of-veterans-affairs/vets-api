# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::VANotifyFollowUpJob, type: :job do
  subject { described_class.new }

  describe '#perform' do
    before do
      allow_any_instance_of(described_class).to receive(:handle_failure).and_return(true)
    end

    let(:notification_id) { '111111-1111-1111-11111111' }

    context 'no retry statues' do
      shared_examples 'does not requeue the job' do |status|
        it "when the status is #{status}" do
          allow(described_class).to receive(:perform_async)
          allow_any_instance_of(described_class).to receive(:notification_response_status).and_return(status)

          subject.perform(notification_id)

          expect(described_class).not_to have_received(:perform_async)
        end
      end

      described_class::NON_RETRY_STATUSES.each do |status|
        include_examples 'does not requeue the job', status.to_s
      end
    end

    context 'retry statues' do
      shared_examples 'requeues the job' do |status|
        it "when the status is #{status}" do
          allow_any_instance_of(described_class).to receive(:notification_response_status).and_return(status)
          expect do
            subject.perform(notification_id)
          end.to raise_error(RuntimeError, "Status for notification #{notification_id} was '#{status}'")
        end
      end

      described_class::RETRY_STATUSES.each do |status|
        include_examples 'requeues the job', status.to_s
      end
    end
  end
end
