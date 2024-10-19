# frozen_string_literal: true

require "rails_helper"
require_relative "../support/helpers/callback_class"

describe VANotify::StatusUpdate do
  describe "#delegate" do
    context "notification with callback" do
      it "returns the callback klass" do
        notification_id = SecureRandom.uuid
        create(:notification, notification_id: notification_id, callback: "OtherTeam::OtherForm")

        provider_callback = {
          id: notification_id
        }

        received_callback = described_class.new.delegate(provider_callback)

        expect(received_callback).to be_an_instance_of(VANotify::Notification)
      end
    end

    context "notification without callback" do
      it "logs the status" do
        notification_id = SecureRandom.uuid
        notification = create(:notification, notification_id: notification_id, callback: nil)

        provider_callback = {
          id: notification_id,
          status: "temporary-failure"
        }

        expect(Rails.logger).to receive(:info).with(source: notification.source_location, status: notification.status)

        described_class.new.delegate(provider_callback)
      end
    end
  end
end
