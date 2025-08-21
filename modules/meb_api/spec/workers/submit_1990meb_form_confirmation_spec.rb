require 'rails_helper'

describe MebApi::V0::Submit1990mebFormConfirmation, type: :worker do
  include ActiveSupport::Testing::TimeHelpers

  let(:email) { 'test@example.com' }
  let(:first_name) { 'TEST' }
  let(:today) { Time.zone.today.strftime('%B %d, %Y') }

  before do
    allow(VANotify::EmailJob).to receive(:perform_async)
  end

  context 'when claim status is ELIGIBLE' do
    before do
      allow(Settings).to receive_message_chain(
        :vanotify, :services, :va_gov, :template_id, :form1990meb_approved_confirmation_email
      ).and_return('approved_template')
    end

    it 'uses the approved template id' do
      travel_to Time.zone.local(2024, 1, 15) do
        expected_date = Time.zone.today.strftime('%B %d, %Y')
        described_class.new.perform('ELIGIBLE', email, first_name)

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          email,
          'approved_template',
          {
            'first_name' => first_name,
            'date_submitted' => expected_date
          }
        )
      end
    end
  end

  context 'when claim status is DENIED' do
    before do
      allow(Settings).to receive_message_chain(
        :vanotify, :services, :va_gov, :template_id, :form1990meb_denied_confirmation_email
      ).and_return('denied_template')
    end

    it 'uses the denied template id' do
      described_class.new.perform('DENIED', email, first_name)

      expect(VANotify::EmailJob).to have_received(:perform_async).with(
        email,
        'denied_template',
        {
          'first_name' => first_name,
          'date_submitted' => today
        }
      )
    end
  end

  context 'when claim status is something else' do
    before do
      allow(Settings).to receive_message_chain(
        :vanotify, :services, :va_gov, :template_id, :form1990meb_offramp_confirmation_email
      ).and_return('offramp_template')
    end

    it 'uses the offramp template id' do
      described_class.new.perform('PENDING', email, first_name)

      expect(VANotify::EmailJob).to have_received(:perform_async).with(
        email,
        'offramp_template',
        {
          'first_name' => first_name,
          'date_submitted' => today
        }
      )
    end
  end
end
