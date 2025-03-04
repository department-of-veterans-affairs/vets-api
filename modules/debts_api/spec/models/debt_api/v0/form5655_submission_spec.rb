# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/sidekiq/va_notify_email_job'

RSpec.describe DebtsApi::V0::Form5655Submission do
  describe 'scopes' do
    let!(:first_record) do
      create(
        :debts_api_form5655_submission,
        public_metadata: { 'streamlined' => { 'type' => 'short', 'value' => true } }
      )
    end
    let!(:second_record) do
      create(
        :debts_api_form5655_submission,
        public_metadata: { 'streamlined' => { 'type' => 'short', 'value' => false } }
      )
    end
    let!(:third_record) { create(:debts_api_form5655_submission, public_metadata: {}) }
    let!(:fourth_record) do
      create(
        :debts_api_form5655_submission,
        public_metadata: { 'streamlined' => { 'type' => 'short', 'value' => nil } }
      )
    end

    it 'includes records within scope' do
      expect(DebtsApi::V0::Form5655Submission.streamlined).to include(first_record)
      expect(DebtsApi::V0::Form5655Submission.streamlined.length).to eq(1)

      expect(DebtsApi::V0::Form5655Submission.not_streamlined).to include(second_record)
      expect(DebtsApi::V0::Form5655Submission.not_streamlined.length).to eq(1)

      expect(DebtsApi::V0::Form5655Submission.streamlined_unclear).to include(third_record)
      expect(DebtsApi::V0::Form5655Submission.streamlined_unclear.length).to eq(1)

      expect(DebtsApi::V0::Form5655Submission.streamlined_nil).to include(fourth_record)
      expect(DebtsApi::V0::Form5655Submission.streamlined_nil.length).to eq(1)
    end
  end

  describe '.upsert_in_progress_form' do
    let(:user) { create(:form5655_submission, '') }
    let(:form5655_submission) { create(:debts_api_form5655_submission, user_uuid: 'b2fab2b56af045e1a9e2394347af91ef') }
    let(:in_progress_form) { create(:in_progress_5655_form, user_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef') }

    context 'without a related InProgressForm' do
      it 'updates the related form' do
        in_progress_form.destroy!
        form = InProgressForm.find_by(form_id: '5655', user_uuid: form5655_submission.user_uuid)
        expect(form).to be_nil

        data = '{"its":"me"}'
        form5655_submission.ipf_data = data
        form5655_submission.upsert_in_progress_form
        form = InProgressForm.find_by(form_id: '5655', user_uuid: form5655_submission.user_uuid)
        expect(form&.form_data).to eq(data)
      end
    end

    context 'with a related InProgressForm' do
      it 'updates the related form' do
        data = '{"its":"me"}'
        form5655_submission
        in_progress_form
        form = InProgressForm.find_by(form_id: '5655', user_uuid: form5655_submission.user_uuid)
        expect(form).to be_present
        expect(form&.form_data).not_to eq(data)

        form5655_submission.ipf_data = data
        form5655_submission.upsert_in_progress_form
        form = InProgressForm.find_by(form_id: '5655', user_uuid: form5655_submission.user_uuid)
        expect(form&.form_data).to eq(data)
      end
    end
  end

  describe '.submit_to_vba' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }
    let(:guy) { create(:form5655_submission) }

    it 'enqueues a VBA submission job' do
      expect do
        form5655_submission.submit_to_vba
      end.to change(DebtsApi::V0::Form5655::VBASubmissionJob.jobs, :size).by(1)
    end
  end

  describe '.submit_to_vha' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }

    it 'enqueues both VHA submission jobs' do
      expect do
        form5655_submission.submit_to_vha
      end
        .to change(DebtsApi::V0::Form5655::VHA::VBSSubmissionJob.jobs, :size).by(1)
        .and change(DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob.jobs, :size).by(1)
    end
  end

  describe '.user_cache_id' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }
    let(:user) { build(:user, :loa3) }

    it 'creates a new User profile attribute' do
      cache_id = form5655_submission.user_cache_id
      attributes = UserProfileAttributes.find(cache_id)
      expect(attributes.class).to eq(UserProfileAttributes)
      expect(attributes.icn).to eq(user.icn)
    end

    context 'with stale user id' do
      before do
        form5655_submission.user_uuid = '00000'
      end

      it 'returns an error' do
        expect { form5655_submission.user_cache_id }.to raise_error(DebtsApi::V0::Form5655Submission::StaleUserError)
      end
    end
  end

  describe '.set_vha_completed_state' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }

    before do
      allow(DebtsApi::V0::Form5655Submission).to receive(:find).and_return(form5655_submission)
    end

    context 'success' do
      let(:status) do
        OpenStruct.new(
          failures: 0,
          failure_info: []
        )
      end

      it 'sets the submission as submitted' do
        described_class.new.set_vha_completed_state(status, { 'submission_id' => form5655_submission.id })
        expect(form5655_submission.submitted?).to be(true)
      end
    end

    context 'failure' do
      let(:id) { SecureRandom.uuid }
      let(:status) do
        OpenStruct.new(
          failures: 1,
          failure_info: [id]
        )
      end

      it 'sets the submission as failed' do
        allow(Rails.logger).to receive(:error)
        described_class.new.set_vha_completed_state(status, { 'submission_id' => form5655_submission.id })
        expect(form5655_submission.error_message).to eq("VHA set completed state: #{id}")
        expect(Rails.logger).to have_received(:error).with('Batch FSR Processing Failed',
                                                           "VHA set completed state: #{id}")
      end
    end
  end

  describe '#register_failure' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }
    let(:message) { 'This is an error message' }

    context 'with debts_silent_failure_mailer Flipper enabled' do
      before do
        ipf_data = get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/ipf/non_streamlined')
        form5655_submission.update(ipf_data: ipf_data.to_json)
      end

      it 'saves error message and logs error' do
        allow(StatsD).to receive(:increment) # Allow StatsD increments to be called without failing the test

        allow(Rails.logger).to receive(:error) # Allows multiple calls

        form5655_submission.register_failure(message)

        expect(Rails.logger).to have_received(:error).at_least(:once) do |log_message, log_message_details|
          # Match multiple formats of the log message
          expect(log_message).to match(/Form5655Submission (Silent error )?id: #{form5655_submission.id}/)
          expect(log_message_details).to include(message) if log_message_details
        end

        expect(StatsD).to receive(:increment).with(
          'silent_failure', { tags: %w[service:debt-resolution function:register_failure] }
        )
        expect(StatsD).to receive(:increment).with(
          'shared.sidekiq.default.DebtManagementCenter_VANotifyEmailJob.enqueue'
        )
        expect(StatsD).to receive(:increment).with(
          'api.fsr_submission.send_failed_form_email.enqueue'
        )
        expect(StatsD).to receive(:increment).with('api.fsr_submission.failure')
        form5655_submission.register_failure(message)
        expect(form5655_submission.error_message).to eq(message)
      end

      it 'saves generic error message with call_location when message is blank' do
        form5655_submission.register_failure(nil)
        expect(form5655_submission.error_message).to start_with(
          'An unknown error occurred while submitting the form from call_location:'
        )
      end

      context 'combined form' do
        it 'saves error message and logs error' do
          form5655_submission.public_metadata = { combined: true }
          form5655_submission.save

          allow(Rails.logger).to receive(:error) # Allows multiple log calls without failing the test

          form5655_submission.register_failure(message)

          # Ensure at least one of the log calls matches the expected pattern
          expect(Rails.logger).to have_received(:error).at_least(:once) do |log_message, log_message_details|
            # Match multiple formats of the log message
            expect(log_message).to match(/Form5655Submission (Silent error )?id: #{form5655_submission.id}/)
            expect(log_message_details).to include(message) if log_message_details
          end

          expect(StatsD).to receive(:increment).with(
            'silent_failure', { tags: %w[service:debt-resolution function:register_failure] }
          )
          expect(StatsD).to receive(:increment).with(
            'shared.sidekiq.default.DebtManagementCenter_VANotifyEmailJob.enqueue'
          )
          expect(StatsD).to receive(:increment).with(
            'api.fsr_submission.send_failed_form_email.enqueue'
          )
          expect(StatsD).to receive(:increment).with('api.fsr_submission.failure')
          expect(StatsD).to receive(:increment).with('api.fsr_submission.combined.failure')
          form5655_submission.register_failure(message)
          expect(form5655_submission.error_message).to eq(message)
        end
      end
    end

    context 'with debts_silent_failure_mailer Flipper disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:debts_silent_failure_mailer).and_return(false)
      end

      it 'saves error message and logs error' do
        allow(Rails.logger).to receive(:error) # Allows multiple log calls without failing the test

        form5655_submission.register_failure(message)

        # Ensure at least one log call matches the expected pattern
        expect(Rails.logger).to have_received(:error).at_least(:once) do |log_message, log_message_details|
          expect(log_message).to match(/Form5655Submission (Silent error )?id: #{form5655_submission.id}/)
          expect(log_message_details).to include(message) if log_message_details
        end

        expect(StatsD).not_to receive(:increment).with(
          'shared.sidekiq.default.DebtManagementCenter_VANotifyEmailJob.enqueue'
        )
        expect(StatsD).not_to receive(:increment).with(
          'api.fsr_submission.send_failed_form_email.enqueue'
        )
        expect(StatsD).to receive(:increment).with('api.fsr_submission.failure')
        form5655_submission.register_failure(message)
        expect(form5655_submission.error_message).to eq(message)
      end

      it 'alerts silent error when not sharepoint error' do
        expect(form5655_submission).to receive(:alert_silent_error)
        form5655_submission.register_failure(message)
      end

      it 'does not alert silent error when sharepoint error' do
        message =
          'VHA set completed state: [#<struct Sidekiq::Batch::Status::Failure jid=\"058f2988d02722166392ff66\", ' \
          'error_class=\"Common::Exceptions::BackendServiceException\", ' \
          'error_message=\"BackendServiceException: {:status=>500, :detail=>\\\"Internal Server Error\\\", ' \
          ':source=>\\\"SharepointRequest\\\", :code=>\\\"SHAREPOINT_PDF_502\\\"}\", backtrace=nil>]'
        expect(form5655_submission).not_to receive(:alert_silent_error)
        form5655_submission.register_failure(message)
      end
    end
  end

  describe '#send_failed_form_email' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }

    before do
      ipf_data = get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/ipf/non_streamlined')
      form5655_submission.update(
        ipf_data: ipf_data.to_json,
        updated_at: Time.new(2025, 1, 1).utc
      )
    end

    context 'with debts_silent_failure_mailer Flipper enabled' do
      it 'sends an email' do
        Timecop.freeze(Time.new(2025, 1, 1).utc) do
          expected_personalization_info = {
            'name' => 'Travis Jones',
            'time' => Time.new(2025, 1, 1).utc,
            'date' => '01/01/2025'
          }

          expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
            'test2@test1.net',
            'fake_template_id',
            expected_personalization_info
          )

          form5655_submission.send_failed_form_email
        end
      end
    end

    context 'with debts_silent_failure_mailer Flipper disabled' do
      it 'does not send an email' do
        allow(Flipper).to receive(:enabled?).with(:debts_silent_failure_mailer).and_return(false)
        expect(DebtManagementCenter::VANotifyEmailJob).not_to receive(:perform_async)
        form5655_submission.send_failed_form_email
      end
    end
  end
end
