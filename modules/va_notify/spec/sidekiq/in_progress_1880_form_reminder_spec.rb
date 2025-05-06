# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

describe VANotify::InProgress1880FormReminder, type: :worker do
  let(:user) { create(:user) }
  let(:in_progress_form) { create(:in_progress_1880_form, user_uuid: user.uuid) }

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

    it 'delegates to VANotify::UserAccountJob' do
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
  end

  def create_in_progress_form_days_ago(count, user_uuid:, form_id:)
    Timecop.freeze(count.days.ago)
    in_progress_form = create(:in_progress_form, user_uuid:, form_id:)
    Timecop.return
    in_progress_form
  end
end
