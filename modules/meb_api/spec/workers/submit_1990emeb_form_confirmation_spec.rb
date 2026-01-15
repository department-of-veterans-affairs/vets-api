# frozen_string_literal: true

require 'rails_helper'

describe MebApi::V0::Submit1990emebFormConfirmation, type: :worker do
  include ActiveSupport::Testing::TimeHelpers

  let(:email) { 'test@example.com' }
  let(:first_name) { 'TEST' }
  let(:user_icn) { '1234567890V123456' }
  let(:today) { Time.zone.today.strftime('%B %d, %Y') }

  before do
    allow(VANotify::EmailJob).to receive(:perform_async)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(StatsD).to receive(:increment)
  end

  context 'when claim status is ELIGIBLE' do
    before do
      template_double = double('template_id', form1990emeb_approved_confirmation_email: 'approved_template')
      allow(Settings.vanotify.services.va_gov).to receive(:template_id).and_return(template_double)
    end

    it 'uses the approved template id' do
      travel_to Time.zone.local(2024, 1, 15) do
        expected_date = Time.zone.today.strftime('%B %d, %Y')
        described_class.new.perform('ELIGIBLE', email, first_name, user_icn)

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
      template_double = double('template_id', form1990emeb_denied_confirmation_email: 'denied_template')
      allow(Settings.vanotify.services.va_gov).to receive(:template_id).and_return(template_double)
    end

    it 'uses the denied template id' do
      described_class.new.perform('DENIED', email, first_name, user_icn)

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
      template_double = double('template_id', form1990emeb_offramp_confirmation_email: 'offramp_template')
      allow(Settings.vanotify.services.va_gov).to receive(:template_id).and_return(template_double)
    end

    it 'uses the offramp template id' do
      described_class.new.perform('PENDING', email, first_name, user_icn)

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

  context 'when a raised error occurs during VANotify::EmailJob' do
    let(:error) { VANotify::Error.new(500, 'Server error') }

    before do
      allow(VANotify::EmailJob).to receive(:perform_async).and_raise(error)
    end

    it 'logs the error and re-raises for Sidekiq retry' do
      expect(Rails.logger).to receive(:error).with(
        'MEB confirmation email enqueue failed',
        hash_including(error_class: 'VANotify::Error')
      )

      expect { described_class.new.perform('PENDING', email, first_name, user_icn) }.to raise_error(VANotify::Error)
    end
  end
end
