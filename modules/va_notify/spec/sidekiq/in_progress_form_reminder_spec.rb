# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

describe VANotify::InProgressFormReminder, type: :worker do
  let(:user) { create(:user) }
  let(:in_progress_form) { create(:in_progress_686c_form, user_uuid: user.uuid) }
  let(:in_progress_form_with_user_account_id) do
    create(:in_progress_686c_form, user_account: create(:user_account))
  end

  describe '#perform' do
    it 'skips sending reminder email if there is no first name' do
      veteran_double = double('VaNotify::Veteran')
      allow(veteran_double).to receive_messages(icn: 'icn', first_name: nil)
      allow(VANotify::Veteran).to receive(:new).and_return(veteran_double)

      allow(VANotify::UserAccountJob).to receive(:perform_async)

      Sidekiq::Testing.inline! do
        described_class.new.perform(in_progress_form.id)
      end

      expect(VANotify::UserAccountJob).not_to have_received(:perform_async)
    end

    describe 'single relevant in_progress_form' do
      it 'delegates to VANotify::UserAccountJob' do
        user_with_uuid = double('VANotify::Veteran', icn: 'icn', first_name: 'first_name', uuid: 'uuid')
        allow(VANotify::Veteran).to receive(:new).and_return(user_with_uuid)

        allow(VANotify::UserAccountJob).to receive(:perform_async)
        expiration_date = in_progress_form_with_user_account_id.expires_at.strftime('%B %d, %Y')

        Sidekiq::Testing.inline! do
          described_class.new.perform(in_progress_form_with_user_account_id.id)
        end

        expect(VANotify::UserAccountJob).to have_received(:perform_async)
          .with(in_progress_form_with_user_account_id.user_account_id, 'fake_template_id',
                {
                  'first_name' => 'FIRST_NAME',
                  'date' => expiration_date,
                  'form_age' => ''
                },
                'fake_secret',
                { callback_metadata: {
                  form_number: '686C-674', notification_type: 'in_progress_reminder', statsd_tags: {
                    'function' => '686C-674 in progress reminder', 'service' => 'va-notify'
                  }
                } })
      end
    end

    describe 'multiple relevant in_progress_forms' do
      let!(:in_progress_form_1) do
        Timecop.freeze(7.days.ago)
        in_progress_form = create(
          :in_progress_686c_form, user_uuid: user.uuid, user_account: create(:user_account)
        )
        Timecop.return
        in_progress_form
      end

      let!(:in_progress_form_2) do
        create_in_progress_form_days_ago(1, user_uuid: user.uuid, form_id: 'form_2_id')
      end

      let!(:in_progress_form_3) do
        create_in_progress_form_days_ago(2, user_uuid: user.uuid, form_id: 'form_3_id')
      end

      it 'skips email if its not the oldest in_progress_form' do
        veteran_double = double('VaNotify::Veteran')
        allow(veteran_double).to receive_messages(icn: 'icn', first_name: 'first_name')
        allow(VANotify::Veteran).to receive(:new).and_return(veteran_double)

        allow(VANotify::UserAccountJob).to receive(:perform_async)
        stub_const('VANotify::FindInProgressForms::RELEVANT_FORMS', %w[686C-674 form_2_id form_3_id])

        Sidekiq::Testing.inline! do
          described_class.new.perform(in_progress_form_3.id)
        end

        expect(VANotify::UserAccountJob).not_to have_received(:perform_async)
      end

      it 'delegates to VANotify::UserAccountJob if its the oldest in_progress_form' do
        Flipper.disable(:in_progress_generic_multiple_template) # rubocop:disable Project/ForbidFlipperToggleInSpecs

        user_with_uuid = double('VANotify::Veteran', icn: 'icn', first_name: 'first_name', uuid: 'uuid')
        allow(VANotify::Veteran).to receive(:new).and_return(user_with_uuid)

        allow(VANotify::UserAccountJob).to receive(:perform_async)
        stub_const('VANotify::FindInProgressForms::RELEVANT_FORMS', %w[686C-674 form_2_id form_3_id])
        stub_const('VANotify::InProgressFormHelper::FRIENDLY_FORM_SUMMARY', {
                     '686C-674' => '686c something',
                     'form_2_id' => 'form_2 something',
                     'form_3_id' => 'form_3 something'
                   })

        stub_const('VANotify::InProgressFormHelper::FRIENDLY_FORM_ID', {
                     '686C-674' => '686C-674',
                     'form_2_id' => 'form_2_example_id',
                     'form_3_id' => 'form_3_example_id'
                   })

        form_1_date = in_progress_form_1.expires_at.strftime('%B %d, %Y')
        form_2_date = in_progress_form_2.expires_at.strftime('%B %d, %Y')
        form_3_date = in_progress_form_3.expires_at.strftime('%B %d, %Y')

        Sidekiq::Testing.inline! do
          described_class.new.perform(in_progress_form_1.id)
        end

        # rubocop:disable Layout/LineLength
        expect(VANotify::UserAccountJob).to have_received(:perform_async).with(in_progress_form_1.user_account_id, 'fake_template_id',
                                                                               {
                                                                                 'first_name' => 'FIRST_NAME',
                                                                                 'formatted_form_data' => "\n^ FORM 686C-674\n^\n^__686c something__\n^\n^_Application expires on:_ #{form_1_date}\n\n\n^---\n\n^ FORM form_3_example_id\n^\n^__form_3 something__\n^\n^_Application expires on:_ #{form_3_date}\n\n\n^---\n\n^ FORM form_2_example_id\n^\n^__form_2 something__\n^\n^_Application expires on:_ #{form_2_date}\n\n"
                                                                               },
                                                                               'fake_secret',
                                                                               { callback_metadata: {
                                                                                 form_number: 'multiple', notification_type: 'in_progress_reminder', statsd_tags: {
                                                                                   'function' => 'multiple in progress reminder', 'service' => 'va-notify'
                                                                                 }
                                                                               } })
        # rubocop:enable Layout/LineLength
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
