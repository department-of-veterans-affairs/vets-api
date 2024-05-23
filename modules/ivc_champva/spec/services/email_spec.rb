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
      file_names: ['file1.pdf', 'file2.pdf'],
      pega_status: 'Processed',
      updated_at: Time.zone.now.to_s
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
          Settings.vanotify.services.va_gov.template_id.ivc_champva_form_callback_email,
          {
            'form_number' => data[:form_number],
            'first_name' => data[:first_name],
            'last_name' => data[:last_name],
            'file_names' => data[:file_names],
            'pega_status' => data[:pega_status],
            'updated_at' => data[:updated_at]
          }
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

      it 'handles the error and returns a 500 status' do
        allow(Datadog::Tracing).to receive(:trace).and_yield

        expect { subject.send_email }.to raise_error(StandardError, 'Test error')
      end
    end
  end
end
