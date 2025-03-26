# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

shared_examples 'an error notification email' do
  it 'increments StatsD' do
    allow(StatsD).to receive(:increment)

    expect { described_class.new(config, notification_type: :error) }.to raise_error(ArgumentError)
    expect(StatsD).to have_received(:increment).with('silent_failure', tags: anything)
  end
end

describe SimpleFormsApi::Notification::FormUploadEmail do
  let(:lighthouse_updated_at) { Time.current }
  let(:form_data) do
    {
      'full_name' => { 'first' => 'Veteran' },
      'email' => 'test@email.com'
    }
  end

  describe '#initialize' do
    context 'when all required arguments are passed in' do
      let(:config) do
        { form_number: '21-0779', form_data:, confirmation_number: 'confirmation-number',
          date_submitted: Time.zone.today.strftime('%B %d, %Y') }
      end

      it 'succeeds' do
        expect { described_class.new(config, notification_type: :confirmation) }.not_to raise_error(ArgumentError)
      end
    end

    context 'missing form_number' do
      let(:config) do
        { form_data:, confirmation_number: 'confirmation-number',
          date_submitted: Time.zone.today.strftime('%B %d, %Y') }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end

    context 'missing form_data' do
      let(:config) do
        { form_number: '21-0779', confirmation_number: 'confirmation-number',
          date_submitted: Time.zone.today.strftime('%B %d, %Y') }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end

    context 'form_data is missing email' do
      let(:config) do
        {
          form_data: { 'full_name' => { 'first' => 'Veteran' } },
          form_number: '21-0779',
          confirmation_number: 'confirmation-number',
          date_submitted: Time.zone.today.strftime('%B %d, %Y')
        }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end

    context 'form_data is missing first_name' do
      let(:config) do
        {
          form_data: { 'email' => 'test@email.com' },
          form_number: '21-0779',
          confirmation_number: 'confirmation-number',
          date_submitted: Time.zone.today.strftime('%B %d, %Y')
        }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end

    context 'missing date_submitted' do
      let(:config) do
        { form_number: '21-0779', form_data:, confirmation_number: 'confirmation-number' }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end

    context 'missing confirmation_number' do
      let(:config) do
        { form_number: '21-0779', form_data:, date_submitted: 'date-submitted' }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end

    context 'form not supported' do
      let(:config) do
        { form_number: 'nonsense', form_data:, confirmation_number: 'confirmation-number',
          date_submitted: Time.zone.today.strftime('%B %d, %Y') }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end
  end

  describe '#send' do
    let(:template_id) { Settings.vanotify.services.va_gov.template_id.form_upload_confirmation_email }
    let(:form_number) { '21-0779' }
    let(:notification_type) { :confirmation }
    let(:confirmation_number) { 'confirmation-number' }
    let(:statsd_tags) do
      {
        'service' => 'veteran-facing-forms',
        'function' => "#{form_number} form upload submission to Lighthouse"
      }
    end
    let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
    let(:email) { 'fake@email.com' }
    let(:full_name) { { 'first' => 'fake', 'last' => 'name' } }
    let(:form_name) { 'fake-form' }
    let(:form_data) do
      { 'email' => email, 'full_name' => full_name, 'form_name' => form_name }
    end
    let(:expected_personalization) do
      {
        'first_name' => full_name['first'].titleize,
        'form_number' => form_number,
        'form_name' => form_name,
        'date_submitted' => date_submitted,
        'confirmation_number' => confirmation_number
      }
    end
    let(:email_args) do
      [
        Settings.vanotify.services.va_gov.api_key,
        { callback_metadata: { notification_type:, form_number:, confirmation_number:, statsd_tags: } }
      ]
    end
    let(:config) do
      { form_number:, form_data:, confirmation_number:, date_submitted: }
    end

    context 'send at time is not specified' do
      it 'sends the email' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = described_class.new(config, notification_type: :confirmation)

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          email,
          template_id,
          expected_personalization,
          *email_args
        )
      end
    end

    context 'send at time is specified' do
      it 'sends the email at the specified time' do
        time = double
        allow(VANotify::EmailJob).to receive(:perform_at)

        subject = described_class.new(config, notification_type: :confirmation)

        subject.send(at: time)

        expect(VANotify::EmailJob).to have_received(:perform_at).with(
          time,
          email,
          template_id,
          expected_personalization,
          *email_args
        )
      end
    end
  end
end
