# frozen_string_literal: true

require 'rails_helper'

def days_since_now(created_at)
  (Time.now.utc - created_at).to_i / 1.day
end

RSpec.describe 'IvcChampva::NotifyPegaMissingFormStatusJob', type: :job do
  let!(:one_hour_ago) { 1.hour.ago.utc }
  let!(:one_hundred_twenty_one_minutes_ago) { 121.minutes.ago.utc }
  let!(:one_week_ago) { 1.week.ago.utc }
  let!(:forms) { create_list(:ivc_champva_form, 3, pega_status: nil, created_at: one_week_ago) }
  let!(:job) { IvcChampva::NotifyPegaMissingFormStatusJob.new }

  before do
    allow(Settings.ivc_forms.sidekiq.missing_form_status_job).to receive(:enabled).and_return(true)
    allow(StatsD).to receive(:increment)

    allow(IvcChampva::Email).to receive(:new).and_return(double(send_email: true))
    allow(job).to receive(:monitor).and_return(double(track_send_zsf_notification_to_pega: nil,
                                                      track_failed_send_zsf_notification_to_pega: nil))
    # Save the original form creation times so we can restore them later
    @original_creation_times = forms.map(&:created_at)
    @original_uuids = forms.map(&:form_uuid)
  end

  after do
    # Restore original dummy form created_at/form_uuid props in case we've adjusted them
    forms.each_with_index do |form, index|
      form.update(created_at: @original_creation_times[index])
      form.update(form_uuid: @original_uuids[index])
    end
  end

  it 'does not run the job when it is disabled in settings' do
    allow(Flipper).to receive(:enabled?).with(:champva_enable_notify_pega_missing_form_status_job).and_return(false)

    expect(Time).not_to receive(:now)
    expect(IvcChampva::NotifyPegaMissingFormStatusJob.new.perform).to be_nil
  end

  it 'identifies forms missing a Pega status for enough hours and attempts to notify PEGA' do
    allow(Flipper).to receive(:enabled?).with(:champva_enable_notify_pega_missing_form_status_job).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:champva_enable_pega_report_check).and_return(false)

    threshold_hours = 2
    allow(Settings.vanotify.services.ivc_champva).to receive(:missing_pega_status_email_threshold_hours)
      .and_return(threshold_hours)
    allow(job).to receive(:send_zsf_notification_to_pega).and_call_original
    allow(job).to receive(:construct_email_payload).and_call_original

    # set forms created_at to one hour ago (under the threshold)
    forms.each do |form|
      form.update(created_at: one_hour_ago)
    end

    # `perform` should identify the forms as not yet lapsed
    job.perform

    # Verify that we did NOT attempt to notify PEGA of anything:
    expect(job).not_to have_received(:send_zsf_notification_to_pega)
    expect(forms[0].reload.email_sent).to be false

    # set forms created_at to 121 minutes ago (over the threshold)
    forms.each do |form|
      form.update(created_at: one_hundred_twenty_one_minutes_ago)
    end

    # `perform` should now identify the forms as lapsed
    job.perform

    # Verify that we attempted to notify PEGA of a missing status:
    expect(job).to have_received(:send_zsf_notification_to_pega).with(anything, 'PEGA-TEAM_MISSING_STATUS')
                                                                .exactly(forms.count).times
    expect(job).not_to have_received(:send_zsf_notification_to_pega).with(anything, 'PEGA-TEAM-ZSF')

    # email_sent should not be true for this form since we only attempted to notify PEGA of a missing status:
    expect(forms[0].reload.email_sent).to be false

    # PII should not have been included in the payload sent for PEGA notifications
    expect(job).to have_received(:construct_email_payload).at_least(:once)
  end

  it 'logs an error if an exception occurs' do
    allow(Flipper).to receive(:enabled?).with(:champva_enable_notify_pega_missing_form_status_job).and_return(true)
    allow(IvcChampvaForm).to receive(:where).and_raise(StandardError.new('Something went wrong'))

    expect(Rails.logger).to receive(:error).twice

    IvcChampva::NotifyPegaMissingFormStatusJob.new.perform
  end

  it 'calls num_docs_match_reports when champva_enable_pega_report_check Flipper flag is enabled' do
    allow(Flipper).to receive(:enabled?).with(:champva_enable_notify_pega_missing_form_status_job).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:champva_enable_pega_report_check).and_return(true)

    batch = [forms[0]]
    missing_form_status_job = instance_double(IvcChampva::MissingFormStatusJob)
    expect(missing_form_status_job).to receive(:num_docs_match_reports?).with(batch)

    allow(job).to receive_messages(missing_form_status_job:,
                                   missing_status_cleanup: double(get_missing_statuses: { some_key: batch }))
    job.perform
  end

  context 'when send_zsf_notification_to_pega is successful' do
    it 'logs a successful notification send to Pega' do
      job.send_zsf_notification_to_pega(forms[0], 'fake-template')

      # Expect our monitor to track the successful send
      expect(job.monitor).to have_received(:track_send_zsf_notification_to_pega).with(forms[0].form_uuid,
                                                                                      'fake-template')
    end
  end

  context 'when send_zsf_notification_to_pega fails' do
    before do
      # Sending the email should fail in this case
      allow(IvcChampva::Email).to receive(:new).and_return(double(send_email: false))
    end

    it 'logs a failed notification send to Pega' do
      job.send_zsf_notification_to_pega(forms[0], 'fake-template')

      # Expect our monitor to track the failed send
      expect(job.monitor).to have_received(:track_failed_send_zsf_notification_to_pega).with(forms[0].form_uuid,
                                                                                             'fake-template')
    end
  end
end
