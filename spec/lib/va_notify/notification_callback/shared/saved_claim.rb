# frozen_string_literal: true

shared_examples_for 'a SavedClaim Notification Callback' do |callback_klass, callback_monitor_klass|
  let(:klass) { callback_klass.to_s.constantize }
  let(:notification) do
    OpenStruct.new(
      notification_id: SecureRandom.uuid,
      notification_type: 'email',
      source_location: 'unit-test',
      status: 'delivered',
      status_reason: 'success',
      callback_klass: klass.to_s,
      callback_metadata: { email_type: :error }
    )
  end
  let(:callback) { klass.new(notification) }
  let(:db_record) { double(ClaimVANotification) }
  let(:monitor_klass) { callback_monitor_klass.to_s.constantize }
  let(:monitor) { double(monitor_klass) }

  before do
    allow(klass).to receive(:new).and_return callback

    allow(ClaimVANotification).to receive(:find_by).and_return db_record
    allow(db_record).to receive(:update)

    allow(monitor_klass).to receive(:new).and_return monitor
    allow(monitor).to receive(:track) # intercept default tracking
  end

  def notification_context
    {
      notification_id: notification.notification_id, # uuid
      notification_type: notification.notification_type,
      notification_status: notification.status
    }
  end

  context 'notification_type == email and email_type == error' do
    describe '#on_deliver' do
      it 'updates database and records silent failure avoided - confirmed' do
        context = hash_including(status: 'delivered')

        expect(db_record).to receive(:update).with(**notification_context)

        expect(monitor_klass).to receive(:new).and_return monitor
        expect(monitor).to receive(:log_silent_failure_avoided).with(context, email_confirmed: true, call_location: nil)

        klass.call(notification)
      end
    end

    describe '#on_permanent_failure' do
      it 'updates database and records silent failure' do
        context = hash_including(status: 'permanent-failure')
        allow(notification).to receive(:status).and_return 'permanent-failure'

        expect(db_record).to receive(:update).with(**notification_context)

        expect(monitor_klass).to receive(:new).and_return monitor
        expect(monitor).to receive(:log_silent_failure).with context, call_location: nil

        klass.call(notification)
      end
    end

    describe '#on_temporary_failure' do
      it 'updates database and no monitoring' do
        allow(notification).to receive(:status).and_return 'temporary-failure'

        expect(db_record).to receive(:update).with(**notification_context)

        klass.call(notification)
      end
    end

    describe '#on_other_status' do
      it 'updates database and no monitoring' do
        allow(notification).to receive(:status).and_return 'other'

        expect(db_record).to receive(:update).with(**notification_context)

        klass.call(notification)
      end
    end
  end

  context 'notification_type == email and email_type != error' do
    before do
      allow(notification).to receive(:callback_metadata).and_return({ email_type: :confirmation })
      allow(callback).to receive(:email_type).and_return :confirmation
    end

    describe '#on_deliver' do
      it 'updates database and no monitoring' do
        expect(db_record).to receive(:update).with(**notification_context)

        klass.call(notification)
      end
    end

    describe '#on_permanent_failure' do
      it 'updates database and no monitoring' do
        allow(notification).to receive(:status).and_return 'permanent-failure'

        expect(db_record).to receive(:update).with(**notification_context)

        klass.call(notification)
      end
    end

    describe '#on_temporary_failure' do
      it 'updates database and no monitoring' do
        allow(notification).to receive(:status).and_return 'temporary-failure'

        expect(db_record).to receive(:update).with(**notification_context)

        klass.call(notification)
      end
    end

    describe '#on_other_status' do
      it 'updates database and no monitoring' do
        allow(notification).to receive(:status).and_return 'other'

        expect(db_record).to receive(:update).with(**notification_context)

        klass.call(notification)
      end
    end
  end

  context 'notification_type != email' do
    before do
      allow(notification).to receive(:notification_type).and_return 'NOT-AN-EMAIL'
    end

    describe '#on_deliver' do
      it 'does not update database and no monitoring' do
        expect(ClaimVANotification).not_to receive(:find_by)

        klass.call(notification)
      end
    end

    describe '#on_permanent_failure' do
      it 'does not update database and no monitoring' do
        allow(notification).to receive(:status).and_return 'permanent-failure'

        expect(ClaimVANotification).not_to receive(:find_by)

        klass.call(notification)
      end
    end

    describe '#on_temporary_failure' do
      it 'does not update database and no monitoring' do
        allow(notification).to receive(:status).and_return 'temporary-failure'

        expect(ClaimVANotification).not_to receive(:find_by)

        klass.call(notification)
      end
    end

    describe '#on_other_status' do
      it 'does not update database and no monitoring' do
        allow(notification).to receive(:status).and_return 'other'

        expect(ClaimVANotification).not_to receive(:find_by)

        klass.call(notification)
      end
    end
  end
end
