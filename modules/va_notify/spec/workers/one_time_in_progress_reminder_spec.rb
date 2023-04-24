# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

describe VANotify::OneTimeInProgressReminder, type: :worker do
  describe '#perform' do
    let(:user_account) { create(:user_account, icn:) }
    let(:icn) { 'icn_here' }
    let(:form_name) { 'some_form_name' }

    context 'sends reminder' do
      it 'delegates to IcnJob to send email' do
        template_id = 'some_template_id'
        personalisation = {
          'some' => 'Fields',
          'thing' => 'data'
        }

        allow(VANotify::IcnJob).to receive(:perform_async)

        Sidekiq::Testing.inline! do
          # only first round should kick off the IcnJob
          described_class.perform_async(user_account.id, form_name, template_id, personalisation)
          # subsequent invocations should do nothing
          described_class.perform_async(user_account.id, form_name, template_id, personalisation)
          described_class.perform_async(user_account.id, form_name, template_id, personalisation)
        end

        # this would fail if VANotify::IcnJob received multiple invocations
        expect(VANotify::IcnJob).to have_received(:perform_async).with('icn_here', 'some_template_id', personalisation)
      end
    end

    context 'does not send reminder' do
      it 'if InProgressRemindersSent model already exists' do
        VANotify::InProgressRemindersSent.create(form_id: form_name, user_account:)

        allow(VANotify::IcnJob).to receive(:perform_async)

        Sidekiq::Testing.inline! do
          described_class.perform_async(user_account.id, form_name, nil, nil)
        end

        expect(VANotify::IcnJob).not_to have_received(:perform_async)
      end

      it 'if creating InProgressRemindersSent fails' do
        allow(VANotify::InProgressRemindersSent).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
        allow(VANotify::IcnJob).to receive(:perform_async)

        expect do
          Sidekiq::Testing.inline! do
            described_class.perform_async(user_account.id, form_name, nil, nil)
          end
        end.to raise_error(ActiveRecord::RecordInvalid)

        expect(VANotify::IcnJob).not_to have_received(:perform_async)
      end
    end
  end
end
