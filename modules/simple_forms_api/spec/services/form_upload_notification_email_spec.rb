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
        { form_number: '21-0779', form_data: {}, confirmation_number: 'confirmation-number',
          date_submitted: Time.zone.today.strftime('%B %d, %Y') }
      end

      it 'succeeds' do
        expect { described_class.new(config, notification_type: :confirmation) }.not_to raise_error(ArgumentError)
      end
    end

    context 'missing form_number' do
      let(:config) do
        { form_data: {}, confirmation_number: 'confirmation-number',
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

    context 'missing date_submitted' do
      let(:config) do
        { form_number: '21-0779', form_data: {}, confirmation_number: 'confirmation-number' }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end

    context 'missing confirmation_number' do
      let(:config) do
        { form_number: '21-0779', form_data: {}, date_submitted: 'date-submitted' }
      end

      it 'fails' do
        expect { described_class.new(config, notification_type: :confirmation) }.to raise_error(ArgumentError)
      end

      it_behaves_like 'an error notification email'
    end

    context 'form not supported' do
      let(:config) do
        { form_number: 'nonsense', form_data: {}, confirmation_number: 'confirmation-number',
          date_submitted: Time.zone.today.strftime('%B %d, %Y') }
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
      { form_number: '21-0779', form_data: {}, confirmation_number: 'confirmation-number', date_submitted: }
    end

    context 'send at time is not specified' do
      it 'sends the email' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = described_class.new(config, notification_type: :confirmation)

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async)
      end
    end

    context 'send at time is specified' do
      it 'sends the email at the specified time' do
        time = double
        allow(VANotify::EmailJob).to receive(:perform_at)

        subject = described_class.new(config, notification_type: :confirmation)

        subject.send(at: time)

        expect(VANotify::EmailJob).to have_received(:perform_at).with(time, anything, anything, anything, anything,
                                                                      anything)
      end
    end
  end
end
