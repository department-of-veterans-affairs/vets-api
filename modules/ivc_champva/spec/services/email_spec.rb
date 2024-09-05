# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::Email, type: :service do
  subject { described_class.new(data) }

  let(:data) do
    {
      email: 'test@example.com',
      form_number: '10-10D',
      first_name: 'John',
      last_name: 'Doe',
      file_count: 3,
      pega_status: 'Processed',
      created_at: Time.zone.now.to_s
    }
  end

  describe '#send_email' do
    context 'in valid environments' do
      before do
        allow(Rails).to receive(:env).and_return('staging')
      end

      it 'traces the sending email process' do
        expect(Datadog::Tracing).to receive(:trace).with('Send PEGA Status Update Email').and_yield
        subject.send_email
      end

      it 'enqueues VANotify::EmailJob with correct parameters' do
        expect(VANotify::EmailJob).to receive(:perform_async).with(
          data[:email],
          Settings.vanotify.services.ivc_champva.template_id.form_10_10d_email,
          {
            'first_name' => data[:first_name],
            'last_name' => data[:last_name],
            'file_count' => data[:file_count],
            'pega_status' => data[:pega_status],
            'date_submitted' => data[:created_at]
          },
          Settings.vanotify.services.ivc_champva.api_key
        )
        subject.send_email
      end
    end

    context 'in invalid environments' do
      before do
        allow(Rails).to receive(:env).and_return('development')
      end

      it 'does not enqueue VANotify::EmailJob' do
        expect(VANotify::EmailJob).not_to receive(:perform_async)
        subject.send_email
      end
    end

    context 'when an error occurs' do
      before do
        allow(Rails).to receive(:env).and_return('staging')
        allow(VANotify::EmailJob).to receive(:perform_async).and_raise(StandardError.new('Test error'))
      end

      it 'handles the error and logs it' do
        allow(Datadog::Tracing).to receive(:trace).and_yield
        allow(Rails.logger).to receive(:error)

        expect { subject.send_email }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with('Pega Status Update Email Error: Test error')
      end
    end
  end
end
