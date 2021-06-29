# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VANotifyEmailJob, type: :model do
  let(:email) { 'user@example.com' }
  let(:template_id) { 'template_id' }

  describe '#perform' do
    it 'sends an email using the template id' do
      client = double
      expect(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.va_gov.api_key).and_return(client)

      expect(client).to receive(:send_email).with(
        email_address: email,
        template_id: template_id
      )

      described_class.new.perform(email, template_id)
    end
  end
end
