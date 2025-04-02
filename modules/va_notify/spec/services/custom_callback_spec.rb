# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/callback_class'

describe VANotify::CustomCallback do
  subject { described_class.new(provider_callback) }

  let(:notification_id) { SecureRandom.uuid }
  let(:provider_callback) do
    {
      id: notification_id
    }
  end

  describe '#call' do
    context 'notification with callback' do
      it 'invokes callback class #call' do
        create(:notification, notification_id:, callback_klass: 'VANotify::OtherTeam::OtherForm')
        allow(VANotify::OtherTeam::OtherForm).to receive(:call)

        subject.call

        expect(VANotify::OtherTeam::OtherForm).to have_received(:call)
      end

      it 'logs error message if #call fails' do
        notification = create(:notification, notification_id:, callback_klass: 'VANotify::OtherTeam::OtherForm')

        allow(notification.callback_klass.constantize).to receive(:call)
          .with(notification).and_raise(StandardError,
                                        'Something went wrong')

        expect(Rails.logger).to receive(:info)
          .with({ message: 'Rescued VANotify::OtherTeam::OtherForm from VANotify::CustomCallback#call' })
        expect(Rails.logger).to receive(:info).with({ source: 'SomeTeam', status: notification.status,
                                                      error_message: 'Something went wrong' })

        subject.call
      end

      it 'logs a message and source location if callback klass does not implement #call' do
        notification = create(:notification, notification_id:,
                                             callback_klass: 'VANotify::NonCompliantModule::NonCompliantClass')

        expect(Rails.logger).to receive(:info).with(message: 'The callback class does not implement #call')
        expect(Rails.logger).to receive(:info).with(source: notification.source_location)

        subject.call
      end
    end

    context 'notification without callback' do
      it 'logs the status' do
        notification = create(:notification, notification_id:)

        expected_error_message = "VANotify - no callback provided for notification: #{notification.id}"

        expect(Rails.logger).to receive(:info).with(message: expected_error_message)

        subject.call
      end
    end
  end
end
