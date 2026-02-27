# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

describe VANotify::InProgress1880FormReminder, type: :worker do
  let(:user) { create(:user) }
  let(:in_progress_form) { create(:in_progress_1880_form, user_uuid: user.uuid) }

  before do
    allow(Flipper).to receive(:enabled?).and_call_original
    allow(Flipper).to receive(:enabled?).with(:va_notify_v2_in_progress_form_reminder).and_return(false)
  end

  describe '#perform' do
    it 'skips sending if ICN is not present' do
      user_without_icn = double('VANotify::Veteran')
      allow(user_without_icn).to receive_messages(first_name: 'first_name', icn: nil)
      allow(VANotify::Veteran).to receive(:new).and_return(user_without_icn)

      allow(VANotify::OneTimeInProgressReminder).to receive(:perform_async)

      Sidekiq::Testing.inline! do
        described_class.new.perform(in_progress_form.id)
      end

      expect(VANotify::OneTimeInProgressReminder).not_to have_received(:perform_async)
    end

    it 'skips sending reminder email if there is no first name' do
      veteran_double = double('VaNotify::Veteran')
      allow(veteran_double).to receive_messages(icn: 'icn', first_name: nil)
      allow(VANotify::Veteran).to receive(:new).and_return(veteran_double)

      allow(VANotify::OneTimeInProgressReminder).to receive(:perform_async)

      Sidekiq::Testing.inline! do
        described_class.new.perform(in_progress_form.id)
      end

      expect(VANotify::OneTimeInProgressReminder).not_to have_received(:perform_async)
    end

    it 'rescues VANotify::Veteran::MPIError and returns nil' do
      allow(VANotify::OneTimeInProgressReminder).to receive(:perform_async)
      allow(VANotify::Veteran).to receive(:new).and_raise(VANotify::Veteran::MPIError)

      result = Sidekiq::Testing.inline! do
        described_class.new.perform(in_progress_form.id)
      end

      expect(result).to be_nil
      expect(VANotify::OneTimeInProgressReminder).not_to have_received(:perform_async)
    end

    it 'rescues VANotify::Veteran::MPINameError and returns nil' do
      allow(VANotify::OneTimeInProgressReminder).to receive(:perform_async)
      allow(VANotify::Veteran).to receive(:new).and_raise(VANotify::Veteran::MPINameError)

      result = Sidekiq::Testing.inline! do
        described_class.new.perform(in_progress_form.id)
      end

      expect(result).to be_nil
      expect(VANotify::OneTimeInProgressReminder).not_to have_received(:perform_async)
    end

    it 'delegates to VANotify::OneTimeInProgressReminder' do
      user_with_icn = double('VANotify::Veteran', icn: 'icn', first_name: 'first_name')
      allow(VANotify::Veteran).to receive(:new).and_return(user_with_icn)

      allow(VANotify::OneTimeInProgressReminder).to receive(:perform_async)
      expiration_date = in_progress_form.expires_at.strftime('%B %d, %Y')

      user_account_id = in_progress_form.user_account.id
      template_id = 'form1880_reminder_email_template_id'

      Sidekiq::Testing.inline! do
        described_class.new.perform(in_progress_form.id)
      end

      expect(VANotify::OneTimeInProgressReminder).to have_received(:perform_async).with(user_account_id,
                                                                                        '26-1880',
                                                                                        template_id,
                                                                                        {
                                                                                          'first_name' => 'FIRST_NAME',
                                                                                          'date' => expiration_date
                                                                                        })
    end

    context 'when va_notify_v2_in_progress_form_reminder is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_notify_v2_in_progress_form_reminder).and_return(true)
      end

      it 'calls V2::QueueUserAccountJob directly, bypassing OneTimeInProgressReminder' do
        user_with_icn = double('VANotify::Veteran', icn: 'icn', first_name: 'first_name')
        allow(VANotify::Veteran).to receive(:new).and_return(user_with_icn)

        allow(VANotify::V2::QueueUserAccountJob).to receive(:enqueue)
        allow(VANotify::OneTimeInProgressReminder).to receive(:perform_async)
        expiration_date = in_progress_form.expires_at.strftime('%B %d, %Y')

        user_account_id = in_progress_form.user_account.id
        template_id = 'form1880_reminder_email_template_id'

        Sidekiq::Testing.inline! do
          described_class.new.perform(in_progress_form.id)
        end

        expect(VANotify::OneTimeInProgressReminder).not_to have_received(:perform_async)
        expect(VANotify::V2::QueueUserAccountJob).to have_received(:enqueue).with(
          user_account_id,
          template_id,
          {
            'first_name' => 'FIRST_NAME',
            'date' => expiration_date
          },
          'Settings.vanotify.services.va_gov.api_key'
        )
      end

      it 'creates an InProgressRemindersSent record' do
        user_with_icn = double('VANotify::Veteran', icn: 'icn', first_name: 'first_name')
        allow(VANotify::Veteran).to receive(:new).and_return(user_with_icn)
        allow(VANotify::V2::QueueUserAccountJob).to receive(:enqueue)

        user_account_id = in_progress_form.user_account.id

        expect do
          Sidekiq::Testing.inline! do
            described_class.new.perform(in_progress_form.id)
          end
        end.to change(VANotify::InProgressRemindersSent, :count).by(1)

        record = VANotify::InProgressRemindersSent.last
        expect(record.user_account_id).to eq(user_account_id)
        expect(record.form_id).to eq('26-1880')
      end

      it 'skips sending if user was already notified' do
        user_with_icn = double('VANotify::Veteran', icn: 'icn', first_name: 'first_name')
        allow(VANotify::Veteran).to receive(:new).and_return(user_with_icn)
        allow(VANotify::V2::QueueUserAccountJob).to receive(:enqueue)

        user_account_id = in_progress_form.user_account.id
        VANotify::InProgressRemindersSent.create!(user_account_id:, form_id: '26-1880')

        Sidekiq::Testing.inline! do
          described_class.new.perform(in_progress_form.id)
        end

        expect(VANotify::V2::QueueUserAccountJob).not_to have_received(:enqueue)
      end
    end
  end

  def create_in_progress_form_days_ago(count, user_uuid:, form_id:)
    Timecop.freeze(count.days.ago)
    in_progress_form = create(:in_progress_form, user_uuid:, form_id:)
    Timecop.return
    in_progress_form
  end
end
