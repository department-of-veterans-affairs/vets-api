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
    let(:form5655_submission) { create(:debts_api_form5655_submission, user_uuid: 'b2fab2b56af045e1a9e2394347af91ef') }
    let(:in_progress_form) { create(:in_progress_5655_form, user_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef') }

    context 'without a related InProgressForm' do
      it 'updates the related form' do
        in_progress_form.destroy!
        form = InProgressForm.find_by(form_id: '5655', user_uuid: form5655_submission.user_uuid)
        expect(form).to be_nil

        data = '{"its":"me"}'
        form5655_submission.ipf_data = data
        form5655_submission.upsert_in_progress_form(user_account: form5655_submission.user_account)
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
        form5655_submission.upsert_in_progress_form(user_account: form5655_submission.user_account)
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
        expect(form5655_submission.error_message).to eq("VHA set completed state: [\"#{id}\"]")
        expect(Rails.logger).to have_received(:error).with('Batch FSR Processing Failed', [id])
      end
    end
  end

  describe '#register_failure' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }
    let(:message) { 'This is an error message' }

    before do
      ipf_data = get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/ipf/non_streamlined')
      form5655_submission.update(ipf_data: ipf_data.to_json)
    end

    it 'saves error message and logs error' do
      expect(Rails.logger).to receive(:error).with("Form5655Submission id: #{form5655_submission.id} failed", message)
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

        expect(Rails.logger).to receive(:error).with(
          "Form5655Submission id: #{form5655_submission.id} failed", message
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

    context 'when Sharepoint error' do
      it 'does not send an email' do
        form5655_submission.register_failure('SharepointRequest')
        expect(DebtManagementCenter::VANotifyEmailJob).not_to receive(:perform_async)
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

    it 'sends an email' do
      Timecop.freeze(Time.new(2025, 1, 1).utc) do
        expected_personalization_info = {
          'first_name' => 'Travis',
          'date_submitted' => '01/01/2025',
          'confirmation_number' => form5655_submission.id,
          'updated_at' => form5655_submission.updated_at
        }

        expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_in).with(
          24.hours,
          'test2@test1.net',
          'fake_template_id',
          expected_personalization_info,
          { id_type: 'email', failure_mailer: true }
        )

        form5655_submission.send_failed_form_email
      end
    end
  end
end
