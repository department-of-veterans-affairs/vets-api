# frozen_string_literal: true

require 'rails_helper'
require 'notifications/client'

describe VaNotify::Service do

  let(:client_url) { Settings['vanotify'].client_url }
  let(:api_key) { Settings['vanotify'].api_key }

  let(:notification_client) { double('Notifications::Client') }

  before do
    allow(Notifications::Client).to receive(:new).and_return(notification_client)
  end

  describe '#send_email' do
    it 'calls notifications client' do
      allow(notification_client).to receive(:send_email)

      subject.send_email(
          email_address: "test@email.com",
          template_id: "1234",
          personalisation: {
              foo: "bar"
          }
      )
      expect(notification_client).to have_received(:send_email).with(
          email_address: "test@email.com",
          template_id: "1234",
          personalisation: {
              foo: "bar"
          }
      )
    end

    it 'overwrites client networking with service perform method' do
      allow(notification_client).to receive(:send_email)
      allow(subject).to receive(:perform)

      subject.send_email('foo')

      expect(subject).to have_received(:perform)
    end
  end

end
