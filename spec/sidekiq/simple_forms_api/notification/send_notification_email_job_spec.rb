# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::Notification::SendNotificationEmailJob, type: :worker do
  subject(:perform) { described_class.new.perform(benefits_intake_uuid, form_number) }

  let(:form_submission_attempt) { create(:form_submission_attempt, :failure) }
  let(:form_number) { 'abc-123' }
  let(:benefits_intake_uuid) { form_submission_attempt.benefits_intake_uuid }

  describe '#perform' do
    shared_examples 'sends notification email' do |email_class|
      let(:notification_email) { instance_double(email_class, send: nil) }

      before do
        allow(email_class).to receive(:new).and_return(notification_email)
      end

      it 'sends the email' do
        perform
        expect(notification_email).to have_received(:send).with(at: anything)
      end

      context 'when email initialization fails' do
        before do
          allow(email_class).to receive(:new).and_raise(ArgumentError)
          allow(StatsD).to receive(:increment)
        end

        it 'increments StatsD' do
          perform
          expect(StatsD).to have_received(:increment).with('silent_failure', tags: anything)
        end
      end
    end

    context 'when submitted with digital form submission tool' do
      let(:form_number) { 'abc-123' }

      it_behaves_like 'sends notification email', SimpleFormsApi::Notification::Email
    end

    context 'when submitted with Form Upload tool' do
      let(:form_number) { '21-0779' }

      it_behaves_like 'sends notification email', SimpleFormsApi::Notification::FormUploadEmail
    end
  end

  describe '.perform_async' do
    subject(:perform_async) { described_class.perform_async(benefits_intake_uuid, form_number) }

    it 'enqueues the job' do
      expect { perform_async }.to change(described_class.jobs, :size).by(1)
    end
  end
end
