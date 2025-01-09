# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/callback_class'

describe VANotify::StatusUpdate do
  subject { described_class.new }

  describe '#delegate' do
    context 'notification with callback' do
      it 'invokes callback class #call' do
        notification_id = SecureRandom.uuid
        create(:notification, notification_id:, callback_klass: 'VANotify::OtherTeam::OtherForm')
        allow(VANotify::OtherTeam::OtherForm).to receive(:call)

        provider_callback = {
          id: notification_id
        }

        subject.delegate(provider_callback)

        expect(VANotify::OtherTeam::OtherForm).to have_received(:call)
      end

      it 'logs error message if #call fails' do
        notification_id = SecureRandom.uuid
        notification = create(:notification, notification_id:, callback_klass: 'VANotify::OtherTeam::OtherForm')
        provider_callback = {
          id: notification_id
        }

        allow(notification.callback_klass.constantize).to receive(:call)
          .with(notification).and_raise(StandardError,
                                        'Something went wrong')

        expect(Rails.logger).to receive(:error).with(source: notification.source_location, status: notification.status,
                                                     error_message: 'Something went wrong')

        subject.delegate(provider_callback)
      end

      it 'logs a message and source location if callback klass does not implement #call' do
        notification_id = SecureRandom.uuid
        notification = create(:notification, notification_id:,
                                             callback_klass: 'VANotify::NonCompliantModule::NonCompliantClass')
        provider_callback = {
          id: notification_id
        }

        error_message = "#{notification.callback_klass} does not implement #call"
        expect(Rails.logger).to receive(:error).with(source: notification.source_location, status: notification.status,
                                                     error_message:)

        subject.delegate(provider_callback)
      end
    end

    context 'notification without callback' do
      it 'logs the status' do
        notification_id = SecureRandom.uuid
        notification = create(:notification, notification_id:)

        provider_callback = {
          id: notification_id
        }

        allow(VANotify::DefaultCallback).to receive(:call)

        expect(VANotify::DefaultCallback).to receive(:call).with(notification)

        subject.delegate(provider_callback)
      end
    end
  end
end
