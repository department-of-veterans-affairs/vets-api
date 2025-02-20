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
      created_at: Time.zone.now.to_s,
      date_submitted: Time.zone.now.to_s,
      form_uuid: '4171e61a-03b5-49f3-8717-dbf340310473'
    }
  end

  describe '#send_email' do
    context 'in valid environments' do
      before do
        allow(Rails).to receive(:env).and_return('staging')
      end

      it 'enqueues VANotify::EmailJob with correct parameters' do
        expect(VANotify::EmailJob).to receive(:perform_async).with(
          data[:email],
          Settings.vanotify.services.ivc_champva.template_id.form_10_10d_email,
          data.slice(:first_name, :last_name, :file_count, :pega_status, :date_submitted, :form_uuid),
          Settings.vanotify.services.ivc_champva.api_key,
          { callback_klass: nil, callback_metadata: nil }
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
        allow(Rails.logger).to receive(:error)

        expect { subject.send_email }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with('Pega Status Update Email Error: Test error')
      end
    end
  end
end
