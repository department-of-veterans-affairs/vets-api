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

    it 'increments StatsD counter' do
      allow(StatsD).to receive(:increment)

      expect(StatsD).to receive(:increment).with(
        "#{DebtsApi::V0::Form5655::VBASubmissionJob::STATS_KEY}.initiated"
      )
      form5655_submission.submit_to_vba
    end
  end

  describe '.submit_to_vha' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }

    context 'when financial_management_vbs_only is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:financial_management_vbs_only).and_return(false)
      end

      it 'enqueues both VHA submission jobs' do
        expect do
          form5655_submission.submit_to_vha
        end
          .to change(DebtsApi::V0::Form5655::VHA::VBSSubmissionJob.jobs, :size)
          .by(1)
          .and change(DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob.jobs, :size).by(1)
      end
    end

    context 'when financial_management_vbs_only is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:financial_management_vbs_only).and_return(true)
      end

      it 'only enqueues the VBS submission job' do
        expect do
          form5655_submission.submit_to_vha
        end.to change(DebtsApi::V0::Form5655::VHA::VBSSubmissionJob.jobs, :size).by(1)
           .and not_change(DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob.jobs, :size)
      end
    end
  end

  describe '.user_cache_id' do
    let(:user) { create(:user, :loa3) }
    let(:form5655_submission) do
      create(:debts_api_form5655_submission, user_uuid: user.uuid, user_account: user.user_account)
    end

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

    it 'sends an email with cache_key instead of user info' do
      Timecop.freeze(Time.new(2025, 1, 1).utc) do
        expected_personalization_info = {
          'first_name' => 'Travis',
          'date_submitted' => '01/01/2025',
          'confirmation_number' => form5655_submission.id,
          'updated_at' => form5655_submission.updated_at
        }

        allow(Sidekiq::AttrPackage).to receive(:create).and_return('test_cache_key')

        expect(Sidekiq::AttrPackage).to receive(:create).with(
          hash_including(
            email: 'test2@test1.net',
            personalisation: expected_personalization_info
          )
        ).and_return('test_cache_key')

        expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_in).with(
          24.hours,
          nil,
          'fake_template_id',
          nil,
          { id_type: 'email', failure_mailer: true, cache_key: 'test_cache_key' }
        )

        form5655_submission.send_failed_form_email
      end
    end

    it 'raises when AttrPackage.create fails' do
      allow(Sidekiq::AttrPackage).to receive(:create).and_raise(
        Sidekiq::AttrPackageError.new('create', 'Redis connection failed')
      )

      expect { form5655_submission.send_failed_form_email }.to raise_error(Sidekiq::AttrPackageError)
    end
  end

  describe '#vba_debt_identifiers' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }

    context 'with VBA debts' do
      before do
        metadata = {
          'debts' => [
            { 'deductionCode' => '30', 'originalAR' => '1000' },
            { 'deductionCode' => '41', 'originalAR' => '500' }
          ]
        }
        form5655_submission.update(
          metadata: metadata.to_json,
          public_metadata: { 'debt_type' => 'DEBT' }
        )
      end

      it 'returns composite debt identifiers' do
        expect(form5655_submission.vba_debt_identifiers).to eq(%w[301000 41500])
      end
    end

    context 'without debts' do
      before do
        metadata = { 'debts' => [] }
        form5655_submission.update(
          metadata: metadata.to_json,
          public_metadata: { 'debt_type' => 'DEBT' }
        )
      end

      it 'returns empty array' do
        expect(form5655_submission.vba_debt_identifiers).to eq([])
      end
    end
  end

  describe '#vha_copay_identifiers' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }

    context 'with VHA copays' do
      before do
        metadata = {
          'copays' => [
            { 'id' => '3fa85f64-5717-4562-b3fc-2c963f66afa6' },
            { 'id' => '2ea85f64-5717-4562-b3fc-2c963f66afa7' }
          ]
        }
        form5655_submission.update(
          metadata: metadata.to_json,
          public_metadata: { 'debt_type' => 'COPAY' }
        )
      end

      it 'returns copay UUIDs' do
        expect(form5655_submission.vha_copay_identifiers).to eq(%w[
                                                                  3fa85f64-5717-4562-b3fc-2c963f66afa6
                                                                  2ea85f64-5717-4562-b3fc-2c963f66afa7
                                                                ])
      end
    end

    context 'without copays' do
      before do
        metadata = { 'copays' => [] }
        form5655_submission.update(
          metadata: metadata.to_json,
          public_metadata: { 'debt_type' => 'COPAY' }
        )
      end

      it 'returns empty array' do
        expect(form5655_submission.vha_copay_identifiers).to eq([])
      end
    end
  end

  describe '#debt_identifiers' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }

    context 'with combined debts and copays' do
      before do
        metadata = {
          'debts' => [
            { 'deductionCode' => '30', 'originalAR' => '1000' }
          ],
          'copays' => [
            { 'id' => '3fa85f64-5717-4562-b3fc-2c963f66afa6' }
          ]
        }
        form5655_submission.update(
          metadata: metadata.to_json,
          public_metadata: { 'combined' => true }
        )
      end

      it 'returns all debt identifiers' do
        expect(form5655_submission.debt_identifiers).to contain_exactly(
          '301000',
          '3fa85f64-5717-4562-b3fc-2c963f66afa6'
        )
      end
    end

    context 'with VBA debts only' do
      before do
        metadata = {
          'debts' => [
            { 'deductionCode' => '30', 'originalAR' => '1000' }
          ]
        }
        form5655_submission.update(
          metadata: metadata.to_json,
          public_metadata: { 'debt_type' => 'DEBT' }
        )
      end

      it 'returns only VBA debt identifiers' do
        expect(form5655_submission.debt_identifiers).to eq(['301000'])
      end
    end

    context 'with VHA copays only' do
      before do
        metadata = {
          'copays' => [
            { 'id' => '3fa85f64-5717-4562-b3fc-2c963f66afa6' }
          ]
        }
        form5655_submission.update(
          metadata: metadata.to_json,
          public_metadata: { 'debt_type' => 'COPAY' }
        )
      end

      it 'returns only VHA copay identifiers' do
        expect(form5655_submission.debt_identifiers).to eq(['3fa85f64-5717-4562-b3fc-2c963f66afa6'])
      end
    end
  end
end
