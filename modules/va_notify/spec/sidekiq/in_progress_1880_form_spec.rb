# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

describe VANotify::InProgress1880Form, type: :worker do
  describe '#perform' do
    it 'creates additional async workers to send messages to va notify' do
      in_progress_form1 = create_in_progress_form_hours_ago(22, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                                                form_id: '26-1880')
      in_progress_form2 = create_in_progress_form_hours_ago(23, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                                                form_id: '26-1880')
      in_progress_form3 = create_in_progress_form_hours_ago(24, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                                                form_id: '26-1880')

      Sidekiq::Testing.inline! do
        expect(VANotify::InProgress1880FormReminder).not_to receive(:perform_async).with(in_progress_form1.id)
        expect(VANotify::InProgress1880FormReminder).to receive(:perform_async).with(in_progress_form2.id)
        expect(VANotify::InProgress1880FormReminder).not_to receive(:perform_async).with(in_progress_form3.id)

        described_class.perform_async
      end
    end
  end

  def create_in_progress_form_hours_ago(count, user_uuid:, form_id:)
    Timecop.freeze(count.hours.ago)
    in_progress_form = create(:in_progress_form, user_uuid:, form_id:)
    Timecop.return
    in_progress_form
  end
end
