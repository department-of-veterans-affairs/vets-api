# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

describe VANotify::ClearStaleInProgressRemindersSent, type: :worker do
  describe '#perform' do
    let(:user_account) { create(:user_account) }

    it 'clears in progress reminders sent after 60 days' do
      create_in_progress_reminder_sent_days_ago(59, form_id: '00-0000')
      create_in_progress_reminder_sent_days_ago(60, form_id: '11-1111')
      create_in_progress_reminder_sent_days_ago(61, form_id: '22-2222')

      Sidekiq::Testing.inline! do
        expect(VANotify::InProgressRemindersSent.all.length).to be(3)

        described_class.perform_async

        expect(VANotify::InProgressRemindersSent.all.length).to be(1)
      end
    end
  end

  def create_in_progress_reminder_sent_days_ago(count, form_id:)
    Timecop.freeze(count.days.ago)
    VANotify::InProgressRemindersSent.create(form_id:, user_account:)
    Timecop.return
  end
end
