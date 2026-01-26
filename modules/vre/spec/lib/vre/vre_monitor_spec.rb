# frozen_string_literal: true

require 'rails_helper'
require 'vre/vre_monitor'

RSpec.describe VRE::VREMonitor do
  let(:monitor) { described_class.new }

  # using the old model until we migrate all functionality to the new module
  let(:claim) { create(:veteran_readiness_employment_claim) }
  # let(:claim) { create(:vre_veteran_readiness_employment_claim) }

  let(:ipf) { create(:in_progress_form) }
  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }
  let(:lh_service) { OpenStruct.new(uuid: 'uuid') }
  let(:message_prefix) { "#{described_class} #{VRE::FORM_ID}" }
  let(:current_user) { create(:user) }

  shared_examples 'create operations tracking' do |status, log_level|
    let(:base_payload) do
      {
        confirmation_number: claim.confirmation_number,
        user_account_uuid: current_user.user_account_uuid,
        in_progress_form_id: ipf.id,
        claim_id: claim.id,
        form_id: claim.form_id,
        tags: monitor.tags
      }
    end

    it "logs sidekiq #{status}" do
      expected_message = case status
                         when 'error'
                           "#{message_prefix} submission to Sidekiq failed"
                         when 'validation_error'
                           "#{message_prefix} submission validation error"
                         else
                           "#{message_prefix} submission to Sidekiq #{status}"
                         end

      expected_stats = case status
                       when 'error'
                         'vre-application.failure'
                       else
                         "vre-application.#{status}"
                       end

      expected_payload = base_payload.merge(
        case status
        when 'error'
          { errors: [], error: nil }
        when 'validation_error'
          { errors: [] }
        else
          {}
        end
      )

      expect(monitor).to receive(:track_request).with(
        log_level,
        expected_message,
        expected_stats,
        call_location: anything,
        **expected_payload
      )

      monitor.public_send("track_create_#{status}", ipf, claim, current_user)
    end
  end

  it_behaves_like 'create operations tracking', 'success', :info
  it_behaves_like 'create operations tracking', 'error', :error
  it_behaves_like 'create operations tracking', 'validation_error', :error

  shared_examples 'tracking other errors' do |error_event|
    let(:monitor_error) { create(:monitor_error) }
    it "tracks #{error_event} scenario" do
      log_message = "#{message_prefix} #{error_event}"
      payload = {
        claim_id: nil,
        confirmation_number: claim.confirmation_number,
        form_id: nil,
        error: monitor_error.message,
        tags: monitor.tags,
        user_account_uuid: current_user.user_account_uuid
      }

      case error_event
      when 'fetching submission failed'
        monitor_fn = -> { monitor.track_show_error(claim.confirmation_number, current_user, monitor_error) }
        statsd_message = claim_stats_key
      when 'submission not found'
        monitor_fn = -> { monitor.track_show404(claim.confirmation_number, current_user, monitor_error) }
        statsd_message = claim_stats_key
      when 'process attachment error'
        payload.merge!(
          in_progress_form_id: ipf.id,
          claim_id: claim.id,
          form_id: claim.form_id,
          errors: []
        )
        payload.delete(:error)
        monitor_fn = -> { monitor.track_process_attachment_error(ipf, claim, current_user) }
        statsd_message = "#{claim_stats_key}.process_attachment_error"
      when 'send_confirmation_email failed'
        log_level = :warn
        payload.merge!(
          claim_id: claim.id,
          form_id: claim.form_id,
          benefits_intake_uuid: lh_service.uuid
        )
        monitor_fn = lambda {
          monitor.track_send_email_failure(
            claim,
            lh_service,
            current_user.uuid,
            'confirmation',
            monitor_error
          )
        }
        statsd_message = "#{submission_stats_key}.send_confirmation_failed"
      when 'send_submitted_email failed'
        log_level = :warn
        payload.merge!(
          claim_id: claim.id,
          form_id: claim.form_id,
          benefits_intake_uuid: lh_service.uuid
        )
        monitor_fn = lambda {
          monitor.track_send_email_failure(claim, lh_service, current_user.uuid, 'submitted', monitor_error)
        }
        statsd_message = "#{submission_stats_key}.send_submitted_failed"
      when 'cleanup failed'
        payload.merge!(
          claim_id: claim.id,
          form_id: claim.form_id,
          benefits_intake_uuid: lh_service.uuid,
          error: monitor_error.message,
          user_account_uuid: current_user.uuid
        )
        payload.delete(:message)
        monitor_fn = -> { monitor.track_file_cleanup_error(claim, lh_service, current_user.uuid, monitor_error) }
        statsd_message = "#{submission_stats_key}.cleanup_failed"
      end

      log_level ||= :error

      expect(monitor).to receive(:track_request).with(
        log_level,
        log_message,
        statsd_message,
        call_location: anything,
        **payload
      )

      monitor_fn.call
    end
  end

  it_behaves_like 'tracking other errors', 'fetching submission failed'
  it_behaves_like 'tracking other errors', 'submission not found'
  it_behaves_like 'tracking other errors', 'process attachment error'
  it_behaves_like 'tracking other errors', 'send_confirmation_email failed'
  it_behaves_like 'tracking other errors', 'send_submitted_email failed'
  it_behaves_like 'tracking other errors', 'cleanup failed'

  shared_examples 'tracking submission' do |monitor_event, has_confirmation_number|
    let(:upload) do
      {
        file: 'pdf-file-path',
        attachments: %w[pdf-attachment1 pdf-attachment2]
      }
    end
    let(:lh_service) { double('LighthouseService', uuid: 'uuid') }
    let(:base_payload) do
      {
        claim_id: claim.id,
        form_id: claim.form_id,
        benefits_intake_uuid: lh_service.uuid,
        confirmation_number: claim.confirmation_number,
        user_account_uuid: current_user.uuid,
        file: upload[:file],
        attachments: upload[:attachments],
        tags: monitor.tags
      }
    end
    let(:monitor_error) { create(:monitor_error) }

    it "tracks #{monitor_event} event#{has_confirmation_number ? '' : ' with no confirmation number'}" do
      log_message = message_prefix
      statsd_key = "#{submission_stats_key}.#{monitor_event}"
      log_level = :info

      # Set up payload and message based on event type
      payload, = case monitor_event
                 when 'begun'
                   log_message += ' submission to LH begun'
                   [base_payload.except(:attachments, :file), nil]
                 when 'attempt'
                   log_message += ' submission to LH attempted'
                   [base_payload, nil]
                 when 'success'
                   log_message += ' submission to LH succeeded'
                   [base_payload.except(:attachments, :file), nil]
                 when 'failure'
                   log_level = :warn
                   log_message += ' submission to LH failed, retrying'
                   [base_payload.except(:attachments, :file).merge(error: monitor_error.message), nil]
                 when 'exhausted'
                   log_level = :error
                   log_message += ' submission to LH exhausted!'
                   msg = { 'args' => [claim.id, current_user.user_account_uuid] }
                   payload = if has_confirmation_number
                               {
                                 confirmation_number: claim.confirmation_number,
                                 user_account_uuid: current_user.user_account_uuid,
                                 form_id: claim.form_id,
                                 claim_id: claim.id,
                                 error: msg,
                                 tags: monitor.tags
                               }
                             else
                               {
                                 confirmation_number: nil,
                                 user_account_uuid: current_user.user_account_uuid,
                                 form_id: nil,
                                 claim_id: claim.id,
                                 error: msg,
                                 tags: monitor.tags
                               }
                             end
                   [payload, msg]
                 end

      expect(monitor).to receive(:track_request).with(
        log_level,
        log_message,
        statsd_key,
        call_location: anything,
        **payload
      )

      case monitor_event
      when 'begun'
        monitor.track_submission_begun(claim, lh_service, current_user.uuid)
      when 'attempt'
        monitor.track_submission_attempted(claim, lh_service, current_user.uuid, upload)
      when 'success'
        monitor.track_submission_success(claim, lh_service, current_user.uuid)
      when 'failure'
        monitor.track_submission_retry(claim, lh_service, current_user.uuid, monitor_error)
      end
    end
  end

  it_behaves_like 'tracking submission', 'begun', true
  it_behaves_like 'tracking submission', 'attempt', true
  it_behaves_like 'tracking submission', 'success', true
  it_behaves_like 'tracking submission', 'failure', true

  describe '#service_name' do
    it 'returns expected name' do
      expect(monitor.send(:service_name)).to eq('vre-application')
    end
  end
end
