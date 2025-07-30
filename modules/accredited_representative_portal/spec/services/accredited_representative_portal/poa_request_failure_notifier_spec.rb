# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe PoaRequestFailureNotifier do
    describe '#call' do
      let(:poa_request) { create(:power_of_attorney_request) }
      let(:notification_double) { instance_double(PowerOfAttorneyRequestNotification, id: 123) }

      before do
        # Stub Flipper feature flags
        allow(Flipper).to receive(:enabled?).with(:ar_poa_request_failure_claimant_notification)
                                            .and_return(claimant_enabled)
        allow(Flipper).to receive(:enabled?).with(:ar_poa_request_failure_rep_notification)
                                            .and_return(rep_enabled)
      end

      context 'when both claimant and representative notifications are enabled' do
        let(:claimant_enabled) { true }
        let(:rep_enabled) { true }

        it 'creates two notifications and enqueues two email jobs' do
          expect(poa_request.notifications).to receive(:create!).with(type: 'enqueue_failed',
                                                                      recipient_type: 'claimant')
                                                                .and_return(notification_double)
          expect(poa_request.notifications).to receive(:create!).with(type: 'enqueue_failed',
                                                                      recipient_type: 'resolver')
                                                                .and_return(notification_double)
          expect(PowerOfAttorneyRequestEmailJob).to receive(:perform_async).twice.with(notification_double.id)

          described_class.new(poa_request).call
        end
      end

      context 'when only claimant notification is enabled' do
        let(:claimant_enabled) { true }
        let(:rep_enabled) { false }

        it 'creates one claimant notification and enqueues one email job' do
          expect(poa_request.notifications).to receive(:create!).with(type: 'enqueue_failed',
                                                                      recipient_type: 'claimant')
                                                                .and_return(notification_double)
          expect(poa_request.notifications).not_to receive(:create!).with(type: 'enqueue_failed',
                                                                          recipient_type: 'resolver')
          expect(PowerOfAttorneyRequestEmailJob).to receive(:perform_async).with(notification_double.id)

          described_class.new(poa_request).call
        end
      end

      context 'when no notifications are enabled' do
        let(:claimant_enabled) { false }
        let(:rep_enabled) { false }

        it 'does not create any notifications or enqueue jobs' do
          expect(poa_request.notifications).not_to receive(:create!)
          expect(PowerOfAttorneyRequestEmailJob).not_to receive(:perform_async)

          described_class.new(poa_request).call
        end
      end
    end
  end
end
