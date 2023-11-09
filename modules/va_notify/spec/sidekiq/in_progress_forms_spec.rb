# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

describe VANotify::InProgressForms, type: :worker do
  describe '#perform' do
    it 'creates additional async workers to send messages to va notify' do
      in_progress_form_1 = create_in_progress_form_days_ago(7, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                                               form_id: '686C-674')
      in_progress_form_2 = create_in_progress_form_days_ago(21, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                                                form_id: '686C-674')

      Sidekiq::Testing.inline! do
        expect(VANotify::InProgressFormReminder).to receive(:perform_async).with(in_progress_form_1.id)
        expect(VANotify::InProgressFormReminder).not_to receive(:perform_async).with(in_progress_form_2.id)

        described_class.perform_async
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
