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

describe SimpleFormsApi::FormUploadNotificationEmail do
  let(:lighthouse_updated_at) { Time.current }

  describe '#initialize' do
    context 'when all required arguments are passed in' do
      let(:config) do
        { form_number: '21-0779', form_name: 'form-name', first_name: 'first-name', email: 'email',
          confirmation_number: 'confirmation-number', date_submitted: Time.zone.today.strftime('%B %d, %Y') }
      end

      it 'succeeds' do
        expect { described_class.new(config, notification_type: :confirmation) }.not_to raise_error(ArgumentError)
      end
    end

    context 'missing form_number' do
      let(:config) do
        { form_name: 'form-name', first_name: 'first-name', email: 'email',
          confirmation_number: 'confirmation-number', date_submitted: Time.zone.today.strftime('%B %d, %Y') }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end

    context 'missing form_name' do
      let(:config) do
        { form_number: '21-0779', first_name: 'first-name', email: 'email',
          confirmation_number: 'confirmation-number', date_submitted: Time.zone.today.strftime('%B %d, %Y') }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end

    context 'missing first_name' do
      let(:config) do
        { form_number: '21-0779', form_name: 'form-name', email: 'email',
          confirmation_number: 'confirmation-number', date_submitted: Time.zone.today.strftime('%B %d, %Y') }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end

    context 'missing email' do
      let(:config) do
        { form_number: '21-0779', form_name: 'form-name', first_name: 'first-name',
          confirmation_number: 'confirmation-number', date_submitted: Time.zone.today.strftime('%B %d, %Y') }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end

    context 'missing date_submitted' do
      let(:config) do
        { form_number: '21-0779', form_name: 'form-name', first_name: 'first-name', email: 'email',
          confirmation_number: 'confirmation-number' }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end

    context 'missing confirmation_number' do
      let(:config) do
        { form_number: '21-0779', form_name: 'form-name', first_name: 'first-name', email: 'email',
          date_submitted: 'date-submitted' }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end

    context 'form not supported' do
      let(:config) do
        { form_number: 'nonsense', form_name: 'form-name', first_name: 'first-name', email: 'email',
          confirmation_number: 'confirmation-number', date_submitted: Time.zone.today.strftime('%B %d, %Y') }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end
  end

  describe '#send' do
    let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
    let(:config) do
      { form_number: '21-0779', form_name: 'form-name', first_name: 'first-name', email: 'email',
        confirmation_number: 'confirmation-number', date_submitted: }
    end

    it 'sends the email' do
      allow(VANotify::EmailJob).to receive(:perform_async)

      subject = described_class.new(config, notification_type: :confirmation)

      subject.send

      expect(VANotify::EmailJob).to have_received(:perform_async)
    end
  end
end
