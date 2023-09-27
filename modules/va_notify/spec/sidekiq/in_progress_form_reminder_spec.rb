# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

describe VANotify::InProgressFormReminder, type: :worker do
  let(:user) { create(:user) }
  let(:in_progress_form) { create(:in_progress_686c_form, user_uuid: user.uuid) }

  describe '#perform' do
    it 'fails if ICN is not present' do
      user_without_icn = double('VANotify::Veteran')
      allow(VANotify::Veteran).to receive(:new).and_return(user_without_icn)
      allow(user_without_icn).to receive(:first_name).and_return('first_name')
      allow(user_without_icn).to receive(:icn).and_return(nil)

      expect do
        described_class.new.perform(in_progress_form.id)
      end.to raise_error(VANotify::InProgressFormReminder::MissingICN,
                         "ICN not found for InProgressForm: #{in_progress_form.id}")
    end

    it 'skips sending reminder email if there is no first name' do
      veteran_double = double('VaNotify::Veteran')
      allow(veteran_double).to receive(:icn).and_return('icn')
      allow(veteran_double).to receive(:first_name).and_return(nil)
      allow(VANotify::Veteran).to receive(:new).and_return(veteran_double)

      allow(VANotify::IcnJob).to receive(:perform_async)

      Sidekiq::Testing.inline! do
        described_class.new.perform(in_progress_form.id)
      end

      expect(VANotify::IcnJob).not_to have_received(:perform_async)
    end

    describe 'single relevant in_progress_form' do
      it 'delegates to VANotify::IcnJob' do
        user_with_icn = double('VANotify::Veteran', icn: 'icn', first_name: 'first_name')
        allow(VANotify::Veteran).to receive(:new).and_return(user_with_icn)

        allow(VANotify::IcnJob).to receive(:perform_async)
        expiration_date = in_progress_form.expires_at.strftime('%B %d, %Y')

        Sidekiq::Testing.inline! do
          described_class.new.perform(in_progress_form.id)
        end

        expect(VANotify::IcnJob).to have_received(:perform_async).with('icn', 'fake_template_id',
                                                                       {
                                                                         'first_name' => 'FIRST_NAME',
                                                                         'date' => expiration_date,
                                                                         'form_age' => ''
                                                                       })
      end
    end

    describe 'multiple relevant in_progress_forms' do
      let!(:in_progress_form_1) do
        Timecop.freeze(7.days.ago)
        in_progress_form = create(:in_progress_686c_form, user_uuid: user.uuid)
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
        allow(veteran_double).to receive(:icn).and_return('icn')
        allow(veteran_double).to receive(:first_name).and_return('first_name')
        allow(VANotify::Veteran).to receive(:new).and_return(veteran_double)

        allow(VANotify::IcnJob).to receive(:perform_async)
        stub_const('VANotify::FindInProgressForms::RELEVANT_FORMS', %w[686C-674 form_2_id form_3_id])

        Sidekiq::Testing.inline! do
          described_class.new.perform(in_progress_form_3.id)
        end

        expect(VANotify::IcnJob).not_to have_received(:perform_async)
      end

      it 'delegates to VANotify::IcnJob if its the oldest in_progress_form' do
        Flipper.disable(:in_progress_generic_multiple_template)

        user_with_icn = double('VANotify::Veteran', icn: 'icn', first_name: 'first_name')
        allow(VANotify::Veteran).to receive(:new).and_return(user_with_icn)

        allow(VANotify::IcnJob).to receive(:perform_async)
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
        expect(VANotify::IcnJob).to have_received(:perform_async).with('icn', 'fake_template_id',
                                                                       {
                                                                         'first_name' => 'FIRST_NAME',

                                                                         'formatted_form_data' => "\n^ FORM 686C-674\n^\n^__686c something__\n^\n^_Application expires on:_ #{form_1_date}\n\n\n^---\n\n^ FORM form_3_example_id\n^\n^__form_3 something__\n^\n^_Application expires on:_ #{form_3_date}\n\n\n^---\n\n^ FORM form_2_example_id\n^\n^__form_2 something__\n^\n^_Application expires on:_ #{form_2_date}\n\n"
                                                                       })
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
