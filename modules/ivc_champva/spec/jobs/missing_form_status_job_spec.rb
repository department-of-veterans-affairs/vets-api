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
  let!(:forms) { create_list(:ivc_champva_form, 3, pega_status: nil, created_at: one_week_ago) }
  let!(:job) { IvcChampva::MissingFormStatusJob.new }

  before do
    allow(Settings.ivc_forms.sidekiq.missing_form_status_job).to receive(:enabled).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:champva_vanotify_custom_callback, @current_user).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:champva_missing_status_verbose_logging, @current_user).and_return(false)
    allow(StatsD).to receive(:gauge)
    allow(StatsD).to receive(:increment)

    allow(IvcChampva::Email).to receive(:new).and_return(double(send_email: true))

    allow(job).to receive(:monitor).and_return(double(log_silent_failure: nil))

    # Save the original form creation times so we can restore them later
    @original_creation_times = forms.map(&:created_at)
    @original_uuids = forms.map(&:form_uuid)
  end

  after do
    # Restore original dummy form created_at/form_uuid props in case we've adjusted them
    forms.each_with_index do |form, index|
      next if form.destroyed?

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

    # Verify that the form is past threshold and has no email sent:
    expect(days_since_now(forms[0].created_at) > threshold).to be true
    expect(forms[0].reload.email_sent).to be false

    # Perform should identify the form as lapsed and send a failure email:
    job.perform

    # Verify that an email has now been sent for the target form:
    expect(forms[0].reload.email_sent).to be true
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

    # Verify that we SHOULD send an email to user for this form
    expect(forms[0].email_sent).to be false
    expect(forms[0].pega_status).to be_nil
    expect(days_since_now(forms[0].created_at) > threshold).to be true

    job.perform

    # Should have no change since `send_email` didn't return true
    expect(forms[0].reload.email_sent).to be false
  end

  context 'when champva_ignore_recent_missing_statuses flag is enabled' do
    it 'ignores forms created within the last 2 hours' do
      allow(Flipper).to receive(:enabled?).with(:champva_ignore_recent_missing_statuses,
                                                @current_user).and_return(true)
      # We created 3 test forms above
      forms[0].update(created_at: 2.hours.ago + 2.minutes) # slightly less than 2 hours ago
      forms[1].update(created_at: 2.hours.ago - 2.minutes) # slightly more than 2 hours ago
      forms[2].update(created_at: 3.hours.ago)

      # Perform the job that checks form statuses
      job.perform

      # Check that forms created in the last 2 hours are ignored
      expect(StatsD).to have_received(:gauge).with('ivc_champva.forms_missing_status.count', forms.count - 1)
    end
  end

  context 'when champva_ignore_recent_missing_statuses flag is disabled' do
    it 'ignores forms created within the last 1 minute' do
      allow(Flipper).to receive(:enabled?).with(:champva_ignore_recent_missing_statuses,
                                                @current_user).and_return(false)
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

  it 'sends form metrics with key tags to DataDog' do
    allow(Flipper).to receive(:enabled?).with(:champva_enable_pega_report_check, @current_user).and_return(false)

    job.perform

    forms.each do |form|
      expected_key = "#{form.form_uuid}_#{form.s3_status}_#{form.created_at.strftime('%Y%m%d_%H%M%S')}"
      expect(StatsD).to have_received(:increment).with('ivc_champva.form_missing_status', tags: ["key:#{expected_key}"])
    end
  end

  context 'verbose logging' do
    before do
      allow(Flipper).to receive(:enabled?).with(:champva_enable_pega_report_check, @current_user).and_return(false)
    end

    it 'logs detailed form information when verbose logging is enabled and batch count is <= 10' do
      allow(Flipper).to receive(:enabled?).with(:champva_missing_status_verbose_logging, @current_user).and_return(true)

      # Ensure we have a small batch
      forms[0].update(form_uuid: 'unique-uuid-1')
      forms[1].update(form_uuid: 'unique-uuid-2')
      forms[2].update(form_uuid: 'unique-uuid-3')

      # Allow all other info logs, but expect the verbose status logs
      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:info)
        .with(/IVC Forms MissingFormStatusJob - Missing status for Form/).exactly(3).times

      job.perform
    end

    it 'does not log detailed information when verbose logging is disabled' do
      allow(Flipper).to receive(:enabled?).with(:champva_missing_status_verbose_logging,
                                                @current_user).and_return(false)

      expect(Rails.logger).not_to receive(:info).with(/IVC Forms MissingFormStatusJob - Missing status for Form/)

      job.perform
    end

    it 'does not log detailed information when batch count > 10 even with verbose logging enabled' do
      allow(Flipper).to receive(:enabled?).with(:champva_missing_status_verbose_logging, @current_user).and_return(true)

      # Remove the original forms so they don't interfere with our test
      forms.each(&:destroy)

      # Create a large batch with the same UUID (11 forms total)
      shared_uuid = SecureRandom.uuid
      large_batch_forms = create_list(:ivc_champva_form, 11, pega_status: nil, created_at: one_week_ago)
      large_batch_forms.each { |form| form.update!(form_uuid: shared_uuid) }

      expect(Rails.logger).not_to receive(:info).with(/IVC Forms MissingFormStatusJob - Missing status for Form/)

      job.perform

      # Clean up the forms we created for this test
      large_batch_forms.each(&:destroy)
    end
  end

  it 'logs an error if an exception occurs' do
    allow(IvcChampvaForm).to receive(:where).and_raise(StandardError.new('Something went wrong'))

    expect(Rails.logger).to receive(:error).twice

    IvcChampva::MissingFormStatusJob.new.perform
  end

  it 'excludes VES JSON files when comparing document counts with Pega reports' do
    # Create a batch with mixed file types including VES JSON
    form_uuid = SecureRandom.uuid
    batch = [
      create(:ivc_champva_form, form_uuid:, file_name: 'main_form.pdf', pega_status: nil),
      create(:ivc_champva_form, form_uuid:, file_name: 'attachment.pdf', pega_status: nil),
      create(:ivc_champva_form, form_uuid:, file_name: "#{form_uuid}_vha_10_10d_ves.json", pega_status: nil)
    ]

    # Mock Pega API to return 2 reports (excluding VES JSON)
    pega_reports = [
      { 'UUID' => form_uuid, 'Status' => 'Processed' },
      { 'UUID' => form_uuid, 'Status' => 'Processed' }
    ]

    allow(job.pega_api_client).to receive(:record_has_matching_report).and_return(pega_reports)
    allow(job.missing_status_cleanup).to receive(:manually_process_batch)

    # Should return true because 2 Pega-processable files match 2 Pega reports
    result = job.num_docs_match_reports?(batch)

    expect(result).to be true
    expect(job.missing_status_cleanup).to have_received(:manually_process_batch).with(batch)

    # Clean up test data
    batch.each(&:destroy)
  end

  it 'catches PegaApiError and logs error without crashing the job' do
    form_uuid = SecureRandom.uuid
    batch = [
      create(:ivc_champva_form, form_uuid:, file_name: 'main_form.pdf', pega_status: nil)
    ]

    # Mock Pega API to raise the namespaced error
    allow(job.pega_api_client).to receive(:record_has_matching_report)
      .and_raise(IvcChampva::PegaApi::PegaApiError.new('Connection timeout'))

    # Expect the error to be logged
    expect(Rails.logger).to receive(:error).with(
      /PegaApiError during report check - form_uuid: #{form_uuid}, error: Connection timeout/
    )

    # Should return false (not reconciled) but not raise an exception
    result = job.num_docs_match_reports?(batch)

    expect(result).to be false

    # Clean up test data
    batch.each(&:destroy)
  end
end
