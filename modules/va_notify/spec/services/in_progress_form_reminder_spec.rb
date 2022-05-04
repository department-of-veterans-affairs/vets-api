# frozen_string_literal: true

require 'rails_helper'

describe VANotify::InProgressFormReminder do
  let(:template_id) { 'template_id' }
  let(:user) { create(:user) }
  let(:in_progress_form) { create(:in_progress_686c_form, user_uuid: user.uuid) }
  let(:notification_client) { double('VaNotify::Service') }

  describe '#call' do
    it 'delegates to VANotify::IcnJob' do
      allow(VANotify::IcnJob).to receive(:perform_async)
      described_class.new.call(in_progress_form.id)
      expiration_date = in_progress_form.expires_at.strftime('%B %d, %Y')
      expect(VANotify::IcnJob).to have_received(:perform_async).with('1013062086V794840', 'fake_template_id',
                                                                     {
                                                                       'first_name' => 'FIRST_NAME',
                                                                       'date' => expiration_date
                                                                     })
    end

    it 'fails if ICN is not present' do
      user_without_icn = double('VANotify::Veteran')
      allow(VANotify::Veteran).to receive(:new).and_return(user_without_icn)
      allow(user_without_icn).to receive(:mpi_icn).and_return(nil)

      expect do
        described_class.new.call(in_progress_form.id)
      end.to raise_error(VANotify::InProgressFormReminder::MissingICN,
                         "ICN not found for InProgressForm: #{in_progress_form.id}")
    end

    it 'fails if it can not parse InProgressForm data (unrecognized form_id)' do
      allow(VaNotify::Service).to receive(:new).and_return(notification_client)

      invalid_form = create(:in_progress_form, form_id: 'invalid_id')

      expect do
        subject.call(invalid_form.id)
      end.to raise_error(VANotify::InProgressFormReminder::UnsupportedForm,
                         "Unsupported form: #{invalid_form.form_id} - InProgressForm: #{invalid_form.id}")
    end
  end
end
