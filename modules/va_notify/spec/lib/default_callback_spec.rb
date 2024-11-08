# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/default_callback'

describe VANotify::DefaultCallback do
  describe '#call' do
    context 'notification of error' do
      let(:notification_type) { :error }

      context 'metadata is provided' do
        let(:metadata) { { notification_type:, statsd_tags: {} }.to_json }

        context 'delivered' do
          let(:notification_record) do
            build(:notification, status: 'delivered', metadata:)
          end

          it 'increments StatsD' do
            allow(StatsD).to receive(:increment)

            VANotify::DefaultCallback.new(notification_record).call

            expect(StatsD).to have_received(:increment).with('silent_failure_avoided', anything)
          end
        end

        context 'permanently failed' do
          let(:notification_record) do
            build(:notification, status: 'permanent-failure', metadata:)
          end

          it 'increments StatsD' do
            allow(StatsD).to receive(:increment)

            VANotify::DefaultCallback.new(notification_record).call

            expect(StatsD).to have_received(:increment).with('silent_failure', anything)
          end
        end
      end
    end

    context 'notification of receipt' do
      let(:notification_type) { :received }

      context 'metadata is provided' do
        let(:metadata) { { notification_type:, statsd_tags: {} }.to_json }

        context 'delivered' do
          let(:notification_record) do
            build(:notification, status: 'delivered', metadata:)
          end

          it 'does not increment StatsD' do
            allow(StatsD).to receive(:increment)

            VANotify::DefaultCallback.new(notification_record).call

            expect(StatsD).not_to have_received(:increment)
          end
        end

        context 'permanent-failure' do
          let(:notification_record) do
            build(:notification, status: 'permanent-failure', metadata:)
          end

          it 'does not increment StatsD' do
            allow(StatsD).to receive(:increment)

            VANotify::DefaultCallback.new(notification_record).call

            expect(StatsD).not_to have_received(:increment)
          end
        end
      end
    end

    context 'metadata is not provided' do
      context 'delivered' do
        let(:notification_record) do
          build(:notification, status: 'delivered')
        end

        it 'increments StatsD' do
          allow(StatsD).to receive(:increment)

          VANotify::DefaultCallback.new(notification_record).call

          expect(StatsD).to have_received(:increment).with('silent_failure_avoided',
                                                           tags: ['service:none-provided', 'function:none-provided'])
        end
      end

      context 'permanently failed' do
        let(:notification_record) do
          build(:notification, status: 'permanent-failure')
        end

        it 'increments StatsD' do
          allow(StatsD).to receive(:increment)

          VANotify::DefaultCallback.new(notification_record).call

          expect(StatsD).to have_received(:increment).with('silent_failure',
                                                           tags: ['service:none-provided', 'function:none-provided'])
        end
      end
    end
  end
end
