# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VANotify::ConfirmationEmail, type: :model do
  describe '.send' do
    it 'returns early if already sent' do
      allow(VANotify::EmailJob).to receive(:perform_async).and_return('email_notification')
      described_class.create(user_uuid_and_form_id: 'user-id_form_id')

      subject = described_class.send(template_id: 'template_id', first_name: 'first_name',
                                     user_uuid_and_form_id: 'user-id_form_id', email_address: 'email_address')
      expect(subject).to be_nil

      expect(VANotify::EmailJob).not_to have_received(:perform_async)
    end

    it 'delegates to the EmailJob to send email' do
      allow(VANotify::EmailJob).to receive(:perform_async).and_return('email_notification')

      subject = described_class.send(template_id: 'template_id', first_name: 'first_name',
                                     user_uuid_and_form_id: 'user-id_form_id', email_address: 'email_address')
      expect(subject).to eq('email_notification')

      expect(VANotify::EmailJob).to have_received(:perform_async).with('email_address', 'template_id', {
                                                                         'date' => Time.now.in_time_zone(
                                                                           'Eastern Time (US & Canada)'
                                                                         )
                                                                                       .strftime('%B %d, %Y'),
                                                                         'first_name' => 'FIRST_NAME'
                                                                       })
    end
  end
end
