# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/default_callback'

describe VANotify::DefaultCallback do
  describe '#call' do
    let(:tags) do
      ['service:service-name',
       'function:function description']
    end

    context 'notification of error' do
      let(:notification_type) { :error }

      let(:tags) do
        ['service:service-name',
         'function:function description']
      end

      context 'metadata is provided with statsd_tags as hash' do
        let(:callback_metadata) do
          { notification_type:, statsd_tags: { 'service' => 'service-name', 'function' => 'function description' } }
        end

        context 'delivered' do
          let(:notification_record) do
            build(:notification, status: 'delivered', callback_metadata:)
          end

          it 'increments StatsD' do
            allow(StatsD).to receive(:increment)

            VANotify::DefaultCallback.new(notification_record).call

            expect(StatsD).to have_received(:increment).with('silent_failure_avoided', tags:)
          end
        end

        context 'temporary failed' do
          let(:notification_record) do
            build(:notification, status: 'temporary-failure', callback_metadata:)
          end

          it 'increments StatsD' do
            allow(StatsD).to receive(:increment)

            VANotify::DefaultCallback.new(notification_record).call

            expect(StatsD).to have_received(:increment).with('silent_failure', tags:)
          end
        end

        context 'permanently failed' do
          let(:notification_record) do
            build(:notification, status: 'permanent-failure', callback_metadata:)
          end

          it 'increments StatsD' do
            allow(StatsD).to receive(:increment)

            VANotify::DefaultCallback.new(notification_record).call

            expect(StatsD).to have_received(:increment).with('silent_failure', tags:)
          end
        end

        context 'missing required statsd_tag keys' do
          let(:callback_metadata) do
            { notification_type:, statsd_tags: {} }
          end
          let(:notification_record) do
            build(:notification, status: 'delivered', callback_metadata:)
          end

          it 'logs error and falls back to call_without_metadata' do
            allow(Rails.logger).to receive(:error)
            allow(StatsD).to receive(:increment)

            VANotify::DefaultCallback.new(notification_record).call

            expect(Rails.logger).to have_received(:error).with(
              'VANotify: Invalid metadata format: Missing required keys in default_callback metadata ' \
              'statsd_tags: service, function',
              { notification_record_id: notification_record.id, template_id: notification_record.template_id }
            )
            expect(StatsD).to have_received(:increment).with(
              'silent_failure_avoided',
              tags: ['service:none-provided', 'function:none-provided']
            )
          end
        end
      end

      context 'metadata is provided with statsd_tags as array' do
        let(:tags) do
          ['service:service-name',
           'function:function description',
           'some-non-required-tag:some-tag']
        end

        let(:callback_metadata) do
          { notification_type:, statsd_tags: tags }
        end

        context 'delivered' do
          let(:notification_record) do
            build(:notification, status: 'delivered', callback_metadata:)
          end

          it 'increments StatsD' do
            allow(StatsD).to receive(:increment)

            VANotify::DefaultCallback.new(notification_record).call

            expect(StatsD).to have_received(:increment).with('silent_failure_avoided', tags:)
          end
        end

        context 'temporary failed' do
          let(:notification_record) do
            build(:notification, status: 'temporary-failure', callback_metadata:)
          end

          it 'increments StatsD' do
            allow(StatsD).to receive(:increment)

            VANotify::DefaultCallback.new(notification_record).call

            expect(StatsD).to have_received(:increment).with('silent_failure', tags:)
          end
        end

        context 'permanently failed' do
          let(:notification_record) do
            build(:notification, status: 'permanent-failure', callback_metadata:)
          end

          it 'increments StatsD' do
            allow(StatsD).to receive(:increment)

            VANotify::DefaultCallback.new(notification_record).call

            expect(StatsD).to have_received(:increment).with('silent_failure', tags:)
          end
        end

        context 'missing required statsd_tag keys' do
          let(:callback_metadata) do
            { notification_type:, statsd_tags: {} }
          end
          let(:notification_record) do
            build(:notification, status: 'delivered', callback_metadata:)
          end

          it 'logs error and falls back to call_without_metadata' do
            allow(Rails.logger).to receive(:error)
            allow(StatsD).to receive(:increment)

            VANotify::DefaultCallback.new(notification_record).call

            expect(Rails.logger).to have_received(:error).with(
              'VANotify: Invalid metadata format: Missing required keys in default_callback metadata ' \
              'statsd_tags: service, function',
              { notification_record_id: notification_record.id, template_id: notification_record.template_id }
            )
            expect(StatsD).to have_received(:increment).with(
              'silent_failure_avoided',
              tags: ['service:none-provided', 'function:none-provided']
            )
          end
        end
      end

      context 'invalid metadata format is provided' do
        let(:callback_metadata) { 'this is not how we should pass metadata' }
        let(:notification_record) do
          build(:notification, status: 'delivered', callback_metadata:)
        end

        it 'logs error and falls back to call_without_metadata' do
          allow(Rails.logger).to receive(:error)
          allow(StatsD).to receive(:increment)

          VANotify::DefaultCallback.new(notification_record).call

          expect(Rails.logger).to have_received(:error).with(
            'VANotify: Invalid metadata format: Invalid metadata statsd_tags format: must be a Hash or Array',
            { notification_record_id: notification_record.id, template_id: notification_record.template_id }
          )
          expect(StatsD).to have_received(:increment).with(
            'silent_failure_avoided',
            tags: ['service:none-provided', 'function:none-provided']
          )
        end
      end
    end

    context 'notification of receipt' do
      let(:notification_type) { :received }

      context 'metadata is provided' do
        let(:callback_metadata) { { notification_type:, statsd_tags: tags } }

        context 'delivered' do
          let(:notification_record) do
            build(:notification, status: 'delivered', callback_metadata:)
          end

          it 'does not increment StatsD' do
            allow(StatsD).to receive(:increment)

            VANotify::DefaultCallback.new(notification_record).call

            expect(StatsD).not_to have_received(:increment)
          end
        end

        context 'temporary-failure' do
          let(:notification_record) do
            build(:notification, status: 'temporary-failure', callback_metadata:)
          end

          it 'does not increment StatsD' do
            allow(StatsD).to receive(:increment)

            VANotify::DefaultCallback.new(notification_record).call

            expect(StatsD).not_to have_received(:increment)
          end
        end

        context 'permanent-failure' do
          let(:notification_record) do
            build(:notification, status: 'permanent-failure', callback_metadata:)
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

      context 'temporary failed' do
        let(:notification_record) do
          build(:notification, status: 'temporary-failure')
        end

        it 'increments StatsD' do
          allow(StatsD).to receive(:increment)

          VANotify::DefaultCallback.new(notification_record).call

          expect(StatsD).to have_received(:increment).with('silent_failure',
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
