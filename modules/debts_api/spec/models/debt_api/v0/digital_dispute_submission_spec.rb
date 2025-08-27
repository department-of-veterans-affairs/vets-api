# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/sidekiq/va_notify_email_job'
require 'debts_api/v0/digital_dispute_submission_service'

RSpec.describe DebtsApi::V0::DigitalDisputeSubmission do
  let(:form_submission) { create(:debts_api_digital_dispute_submission) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user_uuid) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user_account).optional(false) }
  end

  describe '#register_failure' do
    let(:message) { 'Test error message' }

    it 'saves error message and sets failed state' do
      form_submission.register_failure(message)
      expect(form_submission.error_message).to eq(message)
      expect(form_submission.failed?).to be(true)
    end

    context 'in production environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
      end

      context 'when digital_dispute_email_notifications is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:digital_dispute_email_notifications).and_return(true)
        end

        it 'sends failure email' do
          expect(form_submission).to receive(:send_failure_email)
          form_submission.register_failure(message)
        end
      end

      context 'when digital_dispute_email_notifications is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:digital_dispute_email_notifications).and_return(false)
        end

        it 'does not send failure email' do
          expect(form_submission).not_to receive(:send_failure_email)
          form_submission.register_failure(message)
        end
      end
    end

    context 'in non-production environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('development')
      end

      it 'does not send failure email' do
        expect(form_submission).not_to receive(:send_failure_email)
        form_submission.register_failure(message)
      end
    end
  end

  describe '#register_success' do
    it 'sets the submission as submitted' do
      form_submission.register_success
      expect(form_submission.submitted?).to be(true)
    end

    context 'in production environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
      end

      context 'when digital_dispute_email_notifications is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:digital_dispute_email_notifications).and_return(true)
        end

        it 'sends success email' do
          expect(form_submission).to receive(:send_success_email)
          form_submission.register_success
        end
      end

      context 'when digital_dispute_email_notifications is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:digital_dispute_email_notifications).and_return(false)
        end

        it 'does not send success email' do
          expect(form_submission).not_to receive(:send_success_email)
          form_submission.register_success
        end
      end
    end

    context 'in non-production environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('development')
      end

      it 'does not send success email' do
        expect(form_submission).not_to receive(:send_success_email)
        form_submission.register_success
      end
    end
  end

  describe 'email functionality' do
    let(:form_submission) { create(:debts_api_digital_dispute_submission) }
    let(:user) { create(:user, :loa3, uuid: form_submission.user_uuid, email: 'test@example.com', first_name: 'John') }

    describe '#send_failure_email' do
      it 'handles errors gracefully with failure StatsD tracking' do
        allow(User).to receive(:find).and_raise(StandardError.new('User not found'))

        expect(StatsD).to receive(:increment).with("#{described_class::STATS_KEY}.send_failed_form_email.enqueue")
        expect(StatsD).to receive(:increment).with("#{described_class::STATS_KEY}.send_failed_form_email.failure")

        expect { form_submission.send(:send_failure_email) }.not_to raise_error
      end
    end

    describe '#send_success_email' do
      it 'handles errors gracefully with failure StatsD tracking' do
        allow(User).to receive(:find).and_raise(StandardError.new('User not found'))

        expect(StatsD).to receive(:increment).with("#{described_class::STATS_KEY}.send_success_email.enqueue")
        expect(StatsD).to receive(:increment).with("#{described_class::STATS_KEY}.send_success_email.failure")

        expect { form_submission.send(:send_success_email) }.not_to raise_error
      end
    end
  end

  describe '#register_failure blank message handling' do
    it 'sets default error message when blank' do
      form_submission.register_failure('')
      expect(form_submission.error_message).to include('An unknown error occurred')
    end
  end

  describe '#parsed_metadata' do
    context 'with valid metadata' do
      before do
        metadata = {
          'disputes' => [
            { 'composite_debt_id' => 'ABC123' }
          ]
        }
        form_submission.update(metadata: metadata.to_json)
      end

      it 'returns parsed metadata' do
        expect(form_submission.parsed_metadata).to eq({
                                                        disputes: [
                                                          { composite_debt_id: 'ABC123' }
                                                        ]
                                                      })
      end
    end

    context 'with blank metadata' do
      before do
        form_submission.update(metadata: nil)
      end

      it 'returns empty hash' do
        expect(form_submission.parsed_metadata).to eq({})
      end
    end
  end

  describe '#store_public_metadata' do
    before do
      metadata = {
        'disputes' => [
          { 'debt_type' => 'overpayment', 'dispute_reason' => 'incorrect_amount' },
          { 'debt_type' => 'copay', 'dispute_reason' => 'already_paid' }
        ]
      }
      form_submission.update(metadata: metadata.to_json)
    end

    it 'extracts debt types and dispute reasons' do
      form_submission.store_public_metadata

      expect(form_submission.public_metadata['debt_types']).to contain_exactly('overpayment', 'copay')
      expect(form_submission.public_metadata['dispute_reasons']).to contain_exactly('incorrect_amount', 'already_paid')
    end
  end

  describe '#store_debt_identifiers' do
    let(:disputes) do
      [
        { composite_debt_id: 'ABC123' },
        { composite_debt_id: 'DEF456' }
      ]
    end

    it 'stores composite debt IDs' do
      form_submission.store_debt_identifiers(disputes)
      expect(form_submission.debt_identifiers).to eq(%w[ABC123 DEF456])
    end
  end

  describe 'Flipper flag interactions' do
    let(:user) { create(:user, :loa3, email: 'test@example.com') }
    let(:form_submission) { create(:debts_api_digital_dispute_submission, user_uuid: user.uuid) }

    describe 'email notifications behavior' do
      context 'when digital_dispute_email_notifications is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:digital_dispute_email_notifications).and_return(true)
        end

        it 'allows email sending when user has email' do
          service = DebtsApi::V0::DigitalDisputeSubmissionService.new(user, [])
          expect(service.send(:email_notifications_enabled?)).to be(true)
        end

        it 'prevents email sending when user has no email' do
          user_without_email = create(:user, :loa3, email: nil)
          service = DebtsApi::V0::DigitalDisputeSubmissionService.new(user_without_email, [])
          expect(service.send(:email_notifications_enabled?)).to be(false)
        end
      end

      context 'when digital_dispute_email_notifications is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:digital_dispute_email_notifications).and_return(false)
        end

        it 'prevents email sending even when user has email' do
          service = DebtsApi::V0::DigitalDisputeSubmissionService.new(user, [])
          expect(service.send(:email_notifications_enabled?)).to be(false)
        end
      end
    end

    describe 'duplicate prevention behavior' do
      let(:existing_submission) do
        create(:debts_api_digital_dispute_submission,
               user_uuid: user.uuid,
               user_account: user.user_account,
               debt_identifiers: ['ABC123'],
               state: :submitted)
      end

      let(:new_submission) do
        create(:debts_api_digital_dispute_submission,
               user_uuid: user.uuid,
               user_account: user.user_account,
               debt_identifiers: ['ABC123'],
               state: :pending)
      end

      before { existing_submission }

      context 'when digital_dispute_duplicate_prevention is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:digital_dispute_duplicate_prevention).and_return(true)
        end

        it 'detects duplicate submissions' do
          service = DebtsApi::V0::DigitalDisputeSubmissionService.new(user, [])
          expect(service.send(:duplicate_submission_exists?, new_submission)).to be(true)
        end
      end

      context 'when digital_dispute_duplicate_prevention is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:digital_dispute_duplicate_prevention).and_return(false)
        end

        it 'does not check for duplicates' do
          service = DebtsApi::V0::DigitalDisputeSubmissionService.new(user, [])
          expect(service.send(:duplicate_submission_exists?, new_submission)).to be(false)
        end
      end
    end
  end
end
