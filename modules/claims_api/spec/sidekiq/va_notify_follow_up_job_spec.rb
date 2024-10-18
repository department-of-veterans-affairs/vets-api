# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::VANotifyFollowUpJob, type: :job do
  subject { described_class.new }

  describe '#perform' do
    before do
      allow(described_class).to receive(:perform_in)
    end

    let(:notification_id) { '111111-1111-1111-11111111' }

    context 'not rescheduling' do
      shared_examples 'does not reschedule' do |status|
        it "when the status is #{status}" do
          allow_any_instance_of(described_class).to receive(:notification_response_status).and_return(status)

          subject.perform(notification_id)

          expect(described_class).not_to have_received(:perform_in)
        end
      end

      described_class::NON_RETRY_STATUSES.each do |status|
        include_examples 'does not reschedule', status.to_s
      end
    end

    context 'rescheduling' do
      shared_examples 'reschedules for 60 minutes from now' do |status|
        it "when the status is #{status}" do
          allow_any_instance_of(described_class).to receive(:notification_response_status).and_return(status)

          subject.perform(notification_id)

          expect(described_class).to have_received(:perform_in).with(60.minutes, notification_id)
        end
      end

      described_class::RETRY_STATUSES.each do |status|
        include_examples 'reschedules for 60 minutes from now', status.to_s
      end
    end
  end
end
