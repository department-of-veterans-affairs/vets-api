# frozen_string_literal: true

require 'rails_helper'

# Returns the number of days from `created_at` until now.
#
# @param [ActiveSupport::TimeWithZone] created_at property of IvcChampvaForm
def days_since_now(created_at)
  (Time.now.utc - created_at).to_i / 1.day
end

RSpec.describe 'IvcChampva::MissingFormStatusJob', type: :job do
  let!(:one_week_ago) { 1.week.ago.utc }
  let!(:one_hour_ago) { 1.hour.ago.utc }
  let!(:one_hundred_twenty_one_minutes_ago) { 121.minutes.ago.utc }
  let!(:forms) { create_list(:ivc_champva_form, 3, pega_status: nil, created_at: one_week_ago) }
  let!(:job) { IvcChampva::MissingFormStatusJob.new }

  before do
    allow(Settings.ivc_forms.sidekiq.missing_form_status_job).to receive(:enabled).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:champva_vanotify_custom_callback, @current_user).and_return(true)
    allow(StatsD).to receive(:gauge)
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
    allow(Settings.ivc_forms.sidekiq.missing_form_status_job).to receive(:enabled).and_return(false)

    expect(IvcChampva::MissingFormStatusJob.new.perform).to be_nil
    expect(StatsD).not_to have_received(:gauge)
    expect(StatsD).not_to have_received(:increment)
  end

  it 'attempts to send failure email to user if the elapsed days w/out PEGA status exceed the threshold' do
    allow(Flipper).to receive(:enabled?).with(:champva_enable_pega_report_check, @current_user).and_return(false)

    threshold = 5 # using 5 since dummy forms have `created_at` set to 1 week ago
    allow(Settings.vanotify.services.ivc_champva).to receive(:failure_email_threshold_days).and_return(threshold)
    allow(job).to receive(:send_zsf_notification_to_pega).and_call_original

    # Verify that the form is past threshold and has no email sent:
    expect(days_since_now(forms[0].created_at) > threshold).to be true
    expect(forms[0].reload.email_sent).to be false

    # Perform should identify the form as lapsed and send a failure email:
    job.perform

    # Verify that a ZSF email has been sent for the target forms:
    expect(job).to have_received(:send_zsf_notification_to_pega).with(anything,
                                                                      'PEGA-TEAM-ZSF').exactly(forms.count).times
    expect(job).not_to have_received(:send_zsf_notification_to_pega).with(anything, 'PEGA-TEAM_MISSING_STATUS')
    expect(forms[0].reload.email_sent).to be true
  end

  it 'identifies forms missing a Pega status for enough hours and attempts to notify PEGA' do
    allow(Flipper).to receive(:enabled?).with(:champva_enable_pega_report_check, @current_user).and_return(false)

    threshold_hours = 2
    allow(Settings.vanotify.services.ivc_champva).to receive(:missing_pega_status_email_threshold_hours)
      .and_return(threshold_hours)
    allow(job).to receive(:send_zsf_notification_to_pega).and_call_original
    allow(job).to receive(:construct_email_payload_without_pii).and_call_original

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
    expect(job).to have_received(:construct_email_payload_without_pii).at_least(:once)
  end

  it 'checks PEGA reporting API and declines to send failure email if form has actually been processed' do
    # The `pega_status` stored on a form object may be innacurate if the PEGA service
    # had an unrelated failure when attempting to update the status via the API.
    # As a result, we double-check PEGA's reporting API for any submissions that
    # are due to send a "missing status failure email", and bail if they're in that system.
    allow(Flipper).to receive(:enabled?).with(:champva_enable_pega_report_check, @current_user).and_return(true)

    threshold = 5 # using 5 since dummy forms have `created_at` set to 1 week ago
    allow(Settings.vanotify.services.ivc_champva).to receive(:failure_email_threshold_days).and_return(threshold)
    allow(job).to receive(:num_docs_match_reports?).and_return(false) # Default

    # Roll up the form submissions into batches and grab the first for testing
    original_uuid, batch = job.missing_status_cleanup.get_missing_statuses(silent: true).first

    # Mock checking the reporting API to pretend like this form w missing status has
    # been ingested on the PEGA side
    allow(job).to receive(:num_docs_match_reports?).with(batch).and_return(true)

    # Verify that the first batch is past threshold and has no email sent:
    expect(days_since_now(batch[0].created_at) > threshold).to be true
    expect(batch[0].email_sent).to be false

    # Identify the form as lapsed and check PEGA API before sending a failure email:
    job.perform

    # Re-fetch batches to ensure we have updated data
    batches = job.missing_status_cleanup.get_missing_statuses(silent: true)
    batch = batches[original_uuid]

    # Verify that the failure email was not sent for first batch, as it HAS been ingested into PEGA
    expect(batch[0].email_sent).to be false
  end

  it 'does not mark email_sent true when email fails to send' do
    allow(Flipper).to receive(:enabled?).with(:champva_enable_pega_report_check, @current_user).and_return(false)
    threshold = 5
    allow(Settings.vanotify.services.ivc_champva).to receive(:failure_email_threshold_days).and_return(threshold)
    allow(IvcChampva::Email).to receive(:new).and_return(double(send_email: false))
    allow(job.monitor).to receive(:log_silent_failure).and_return(nil)

    # Verify that we SHOULD send an email to user for this form
    expect(forms[0].email_sent).to be false
    expect(forms[0].pega_status).to be_nil
    expect(days_since_now(forms[0].created_at) > threshold).to be true

    job.perform

    # Should have no change since `send_email` didn't return true
    expect(forms[0].reload.email_sent).to be false
  end

  it 'ignores forms created within the last 1 minute' do
    # We created 3 test forms above
    forms[0].update(created_at: Time.zone.now) # Created within the last minute
    # Created more than 1 minute ago
    forms[1].update(created_at: 2.minutes.ago)
    forms[2].update(created_at: 3.minutes.ago)

    # Perform the job that checks form statuses
    job.perform

    # Check that forms created in the last minute are ignored
    expect(StatsD).to have_received(:gauge).with('ivc_champva.forms_missing_status.count', forms.count - 1)
  end

  it 'processes nil forms in batches that belong to the same submission' do
    allow(Flipper).to receive(:enabled?).with(:champva_enable_pega_report_check, @current_user).and_return(false)
    # Set shared `form_uuid` so these two now belong to the same batch:
    forms[0].update(form_uuid: '78444a0b-3ac8-454d-a28d-8d63cddd0d3b')
    forms[1].update(form_uuid: '78444a0b-3ac8-454d-a28d-8d63cddd0d3b')

    # Perform the job that checks form statuses
    job.perform

    # Check that we processed batches rather than individual forms:
    expect(StatsD).to have_received(:gauge).with('ivc_champva.forms_missing_status.count', forms.count - 1)
  end

  it 'groups nil statuses into batches by uuid' do
    # Set shared `form_uuid` so these two now belong to the same batch:
    forms[0].update(form_uuid: '78444a0b-3ac8-454d-a28d-8d63cddd0d3b')
    forms[1].update(form_uuid: '78444a0b-3ac8-454d-a28d-8d63cddd0d3b')

    # Perform the job that checks form statuses
    batches = job.missing_status_cleanup.get_missing_statuses(silent: true)

    expect(batches.count == forms.count - 1).to be true
    expect(batches['78444a0b-3ac8-454d-a28d-8d63cddd0d3b'].count == 2).to be true
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
