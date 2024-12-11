# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'IvcChampva::MissingFormStatusJob', type: :job do
  let!(:one_week_ago) { 1.week.ago.utc }
  let!(:forms) { create_list(:ivc_champva_form, 3, pega_status: nil, created_at: one_week_ago) }
  let!(:job) { IvcChampva::MissingFormStatusJob.new }

  before do
    allow(Settings.ivc_forms.sidekiq.missing_form_status_job).to receive(:enabled).and_return(true)
    allow(StatsD).to receive(:gauge)
    allow(StatsD).to receive(:increment)

    allow(IvcChampva::Email).to receive(:new).and_return(double(send_email: true))
    allow(job).to receive(:monitor).and_return(double(track_send_zsf_notification_to_pega: nil,
                                                      track_failed_send_zsf_notification_to_pega: nil))
  end

  it 'sends the count of forms to DataDog' do
    IvcChampva::MissingFormStatusJob.new.perform

    expect(StatsD).to have_received(:gauge).with('ivc_champva.forms_missing_status.count', forms.count)
  end

  it 'logs an error if an exception occurs' do
    allow(IvcChampvaForm).to receive(:where).and_raise(StandardError.new('Something went wrong'))

    expect(Rails.logger).to receive(:error).twice

    IvcChampva::MissingFormStatusJob.new.perform
  end

  context 'when send_zsf_notification_to_pega is successful' do
    it 'logs a successful notification send to Pega' do
      job.send_zsf_notification_to_pega(forms[0])

      # Expect our monitor to track the successful send
      expect(job.monitor).to have_received(:track_send_zsf_notification_to_pega).with(forms[0].form_uuid)
    end
  end

  context 'when send_zsf_notification_to_pega fails' do
    before do
      # Sending the email should fail in this case
      allow(IvcChampva::Email).to receive(:new).and_return(double(send_email: false))
    end

    it 'logs a failed notification send to Pega' do
      job.send_zsf_notification_to_pega(forms[0])

      # Expect our monitor to track the failed send
      expect(job.monitor).to have_received(:track_failed_send_zsf_notification_to_pega).with(forms[0].form_uuid)
    end
  end
end
