# frozen_string_literal: true

require 'rails_helper'
require 'veteran_facing_services/notification_callback'

RSpec.describe VeteranFacingServices::NotificationCallback::Default do
  let(:klass) { VeteranFacingServices::NotificationCallback::Default }
  let(:notification) do
    OpenStruct.new(
      notification_id: SecureRandom.uuid,
      notification_type: 'email',
      source_location: 'unit-test',
      status: 'delivered',
      status_reason: 'success',
      callback_klass: klass.to_s,
      callback_metadata: { foo: 'bar' }
    )
  end
  let(:callback) { klass.new(notification) }
  let(:monitor) { double(Logging::Monitor) }
  let(:metric) { klass::STATSD }

  describe 'VeteranFacingServices::NotificationCallback::Default.call' do
    it 'raises an error if callback class does not match notification.callback_klass' do
      allow(notification).to receive(:callback_klass).and_return('FOOBAR')

      expected_error = VeteranFacingServices::NotificationCallback::CallbackClassMismatch

      expect { klass.call(notification) }.to raise_exception expected_error
    end

    context 'correct class is called for the notification' do
      before do
        allow(klass).to receive(:new).and_return callback
        allow(Logging::Monitor).to receive(:new).with(klass.to_s).and_return monitor
      end

      it 'tracks a `delivered` notification' do
        context = hash_including(status: 'delivered')

        expect(callback).to receive(:on_delivered)
        expect(monitor).to receive(:track).with(:info, "#{callback.klass}: Delivered", "#{metric}.delivered",
                                                context)

        klass.call(notification)
      end

      it 'tracks a `permanent-failure` notification' do
        allow(notification).to receive(:status).and_return 'permanent-failure'
        context = hash_including(status: 'permanent-failure')

        expect(callback).to receive(:on_permanent_failure)
        expect(monitor).to receive(:track).with(:error, "#{callback.klass}: Permanent Failure",
                                                "#{metric}.permanent_failure", context)

        klass.call(notification)
      end

      it 'tracks a `temporary-failure` notification' do
        allow(notification).to receive(:status).and_return 'temporary-failure'
        context = hash_including(status: 'temporary-failure')

        expect(callback).to receive(:on_temporary_failure)
        expect(monitor).to receive(:track).with(:warn, "#{callback.klass}: Temporary Failure",
                                                "#{metric}.temporary_failure", context)

        klass.call(notification)
      end

      it 'tracks a `other` status notification' do
        allow(notification).to receive(:status).and_return 'other'
        context = hash_including(status: 'other')

        expect(callback).to receive(:on_other_status)
        expect(monitor).to receive(:track).with(:warn, "#{callback.klass}: Other", "#{metric}.other", context)

        klass.call(notification)
      end
    end
  end
end
