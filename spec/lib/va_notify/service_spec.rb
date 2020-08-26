# frozen_string_literal: true

require 'rails_helper'
require 'notifications/client'

describe VaNotify::Service do
  before do
    allow_any_instance_of(described_class).to receive(:api_key).and_return('test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
    allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return('http://fakeapi.com')
  end

  describe '#send_email' do
    let(:notification_client) { double('Notifications::Client') }
    it 'calls notifications client' do
      allow(Notifications::Client).to receive(:new).and_return(notification_client)
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
  end

  describe 'error handling' do
    it 'raises a 400 exception' do
      VCR.use_cassette('va_notify/bad_request') do
        expect {
          subject.send_email(
            email_address: "test@email.com",
            template_id: "1234",
            personalisation: {
                foo: "bar"
            }
          )
        }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
          expect(e.status_code).to eq(400)
          expect(e.errors.first.code).to eq('VANOTIFY_400')
        end
      end
    end
  end

end
