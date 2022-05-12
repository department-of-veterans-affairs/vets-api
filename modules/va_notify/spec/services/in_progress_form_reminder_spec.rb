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
      allow(user_without_icn).to receive(:mpi_icn).and_return(nil)

      expect do
        described_class.new.perform(in_progress_form.id)
      end.to raise_error(VANotify::InProgressFormReminder::MissingICN,
                         "ICN not found for InProgressForm: #{in_progress_form.id}")
    end

    it 'fails if it can not parse InProgressForm data (unrecognized form_id)' do
      invalid_form = create(:in_progress_form, form_id: 'invalid_id')

      expect do
        described_class.new.perform(invalid_form.id)
      end.to raise_error(VANotify::InProgressFormHelper::UnsupportedForm,
                         "Unsupported form: #{invalid_form.form_id} - InProgressForm: #{invalid_form.id}")
    end

    describe 'single relevant in_progress_form' do
      it 'delegates to VANotify::IcnJob' do
        allow(VANotify::IcnJob).to receive(:perform_async)
        expiration_date = in_progress_form.expires_at.strftime('%B %d, %Y')

        Sidekiq::Testing.inline! do
          described_class.new.perform(in_progress_form.id)
        end

        expect(VANotify::IcnJob).to have_received(:perform_async).with('1013062086V794840', 'fake_template_id',
                                                                       {
                                                                         'first_name' => 'FIRST_NAME',
                                                                         'date' => expiration_date
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
        allow(veteran_double).to receive(:mpi_icn).and_return('mpi_icn')
        allow(veteran_double).to receive(:first_name).and_return('first_name')
        allow(VANotify::InProgressFormHelper).to receive(:veteran_data).and_return(veteran_double)

        allow(VANotify::IcnJob).to receive(:perform_async)
        stub_const('VANotify::FindInProgressForms::RELEVANT_FORMS', %w[686C-674 form_2_id form_3_id])

        Sidekiq::Testing.inline! do
          described_class.new.perform(in_progress_form_3.id)
        end

        expect(VANotify::IcnJob).not_to have_received(:perform_async)
      end

      it 'delegates to VANotify::IcnJob if its the oldest in_progress_form' do
        allow(VANotify::IcnJob).to receive(:perform_async)
        stub_const('VANotify::FindInProgressForms::RELEVANT_FORMS', %w[686C-674 form_2_id form_3_id])
        stub_const('VANotify::InProgressFormHelper::FRIENDLY_FORM_SUMMARY', {
                     '686C-674' => '686c something',
                     'form_2_id' => 'form_2 something',
                     'form_3_id' => 'form_3 something'
                   })

        form_1_date = "_Application expires on: #{in_progress_form_1.expires_at.strftime('%B %d, %Y')}_"
        form_2_date = "_Application expires on: #{in_progress_form_2.expires_at.strftime('%B %d, %Y')}_"
        form_3_date = "_Application expires on: #{in_progress_form_3.expires_at.strftime('%B %d, %Y')}_"

        Sidekiq::Testing.inline! do
          described_class.new.perform(in_progress_form_1.id)
        end

        expect(VANotify::IcnJob).to have_received(:perform_async).with('1013062086V794840', 'fake_template_id',
                                                                       {
                                                                         'first_name' => 'FIRST_NAME',

                                                                         'form_1_number' => 'FORM 686C-674',
                                                                         'form_1_name' => '__ 686c something __',
                                                                         'form_1_date' => form_1_date,
                                                                         'form_1_divider' => '---',

                                                                         'form_2_number' => 'FORM form_3_id',
                                                                         'form_2_name' => '__ form_3 something __',
                                                                         'form_2_date' => form_3_date,
                                                                         'form_2_divider' => '---',

                                                                         'form_3_number' => 'FORM form_2_id',
                                                                         'form_3_name' => '__ form_2 something __',
                                                                         'form_3_date' => form_2_date,
                                                                         'form_3_divider' => '---'
                                                                       })
      end
    end
  end

  def create_in_progress_form_days_ago(count, user_uuid:, form_id:)
    Timecop.freeze(count.days.ago)
    in_progress_form = create(:in_progress_form, user_uuid: user_uuid, form_id: form_id)
    Timecop.return
    in_progress_form
  end
end
