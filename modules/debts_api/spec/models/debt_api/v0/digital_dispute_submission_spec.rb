# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/sidekiq/va_notify_email_job'

RSpec.describe DebtsApi::V0::DigitalDisputeSubmission do
  let(:form_submission) { create(:debts_api_digital_dispute_submission) }

  describe 'validations' do
    subject { form_submission }

    it { is_expected.to validate_presence_of(:user_uuid) }
    it { is_expected.to validate_uniqueness_of(:guid).ignoring_case_sensitivity }
  end

  describe 'file validations' do
    subject(:submission) { create(:debts_api_digital_dispute_submission) }

    context 'when no files attached' do
      before { submission.files.purge }

      it { is_expected.not_to be_valid }

      it 'has appropriate error' do
        submission.valid?
        expect(submission.errors[:files]).to include(/Invalid file/)
      end
    end

    context 'when file is too large' do
      before do
        submission.files.purge
        large_content = "%PDF-#{'x' * ((2 * 1024 * 1024) - 5)}" # 2MB with PDF header
        submission.files.attach(
          io: StringIO.new(large_content),
          filename: 'large.pdf',
          content_type: 'application/pdf'
        )
      end

      it { is_expected.not_to be_valid }

      it 'has size error' do
        expect(Rails.logger).to receive(:error).with(/file size must be less than 1 MB/)
        submission.valid?
        expect(submission.errors[:files]).to include(/Invalid file/)
      end
    end

    context 'when file is not a PDF' do
      before do
        submission.files.purge
        submission.files.attach(
          io: StringIO.new('plain text content'),
          filename: 'document.txt',
          content_type: 'text/plain'
        )
      end

      it { is_expected.not_to be_valid }

      it 'has content type error' do
        expect(Rails.logger).to receive(:error).with(/has an invalid content type/)
        submission.valid?
        expect(submission.errors[:files]).to include(/Invalid file/)
      end
    end

    context 'when file is valid' do
      it { is_expected.to be_valid }
    end

    context 'when content-type is spoofed' do
      before do
        submission.files.purge
        submission.files.attach(
          io: StringIO.new("MZ\x90\x00"),
          filename: 'virus.exe',
          content_type: 'application/pdf'
        )
      end

      it 'rejects the file' do
        expect(submission).not_to be_valid
      end

      it 'has PDF-related error' do
        expect(Rails.logger).to receive(:error).with(/has an invalid content type/)
        submission.valid?
        expect(submission.errors[:files]).to include(/Invalid file/)
      end
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user_account).optional(false) }

    it 'retrieves debt_transaction_logs by guid' do
      log = create(:debt_transaction_log,
                   transactionable_type: 'DebtsApi::V0::DigitalDisputeSubmission',
                   transactionable_id: form_submission.guid)
      expect(form_submission.debt_transaction_logs).to include(log)
    end
  end

  describe '#register_failure' do
    let(:message) { 'Test error message' }

    it 'saves and logs error message and sets failed state' do
      expect(Rails.logger).to receive(:error).with('DigitalDisputeSubmission error_message: Test error message')
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

      it 'enqueues failure email when user is found' do
        allow(User).to receive(:find).with(form_submission.user_uuid).and_return(user)
        allow(Sidekiq::AttrPackage).to receive(:create).and_return('cache_key_123')

        expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_in).with(
          24.hours,
          nil,
          described_class::FAILURE_TEMPLATE,
          nil,
          hash_including(id_type: 'email', failure_mailer: true, cache_key: 'cache_key_123')
        )

        form_submission.send(:send_failure_email)
      end
    end

    describe '#send_success_email' do
      it 'handles errors gracefully with failure StatsD tracking' do
        allow(User).to receive(:find).and_raise(StandardError.new('User not found'))

        expect(StatsD).to receive(:increment).with("#{described_class::STATS_KEY}.send_success_email.enqueue")
        expect(StatsD).to receive(:increment).with("#{described_class::STATS_KEY}.send_success_email.failure")

        expect { form_submission.send(:send_success_email) }.not_to raise_error
      end

      it 'enqueues confirmation email when user is found' do
        allow(User).to receive(:find).with(form_submission.user_uuid).and_return(user)
        allow(Sidekiq::AttrPackage).to receive(:create).and_return('cache_key_123')

        expect(DebtsApi::V0::Form5655::SendConfirmationEmailJob).to receive(:perform_async).with(
          hash_including(
            'submission_type' => 'digital_dispute',
            'cache_key' => 'cache_key_123',
            'user_uuid' => user.uuid,
            'template_id' => described_class::CONFIRMATION_TEMPLATE
          )
        )

        form_submission.send(:send_success_email)
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
end
