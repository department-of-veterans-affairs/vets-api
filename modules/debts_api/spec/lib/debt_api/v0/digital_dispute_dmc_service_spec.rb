# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/digital_dispute_dmc_service'

RSpec.describe DebtsApi::V0::DigitalDisputeDmcService do
  let(:user) { create(:user, :loa3) }

  let(:pdf_file_one) do
    fixture_file_upload('spec/fixtures/pdf_fill/686C-674/tester.pdf', 'application/pdf')
  end

  let(:pdf_file_two) do
    fixture_file_upload('spec/fixtures/pdf_fill/686C-674-V2/tester.pdf', 'application/pdf')
  end

  # Persist a submission and attach files so Active Storage has blobs
  def build_submission_with_files(*files)
    create(:debts_api_digital_dispute_submission,
           user_uuid: user.uuid,
           user_account: user.user_account,
           state: :pending).tap do |sub|
      sub.files.purge if sub.files.attached? # clear any factory defaults
      sub.files.attach(files)
      sub.save!
    end
  end

  describe '#call!' do
    context 'with valid attachments' do
      it 'posts expected payload and marks submission as submitted' do
        submission = build_submission_with_files(pdf_file_one)

        expect_any_instance_of(described_class).to receive(:perform).with(
          :post,
          'dispute-debt',
          satisfy do |payload|
            expect(payload[:fileNumber]).to eq(user.ssn)

            expect(payload[:disputePDFs].size).to eq(1)
            pdf = payload[:disputePDFs].first
            expect(pdf[:fileName]).to eq('tester.pdf')
            expect(pdf[:fileContents]).to be_a(String)
            expect(Base64.decode64(pdf[:fileContents])).to include('%PDF')
            true
          end
        ).and_return(true)

        described_class.new(user, submission).call!
      end

      it 'handles multiple PDFs' do
        submission = build_submission_with_files(pdf_file_one, pdf_file_two)

        expect_any_instance_of(described_class).to receive(:perform).with(
          :post,
          'dispute-debt',
          satisfy do |payload|
            expect(payload[:fileNumber]).to eq(user.ssn)
            expect(payload[:disputePDFs].size).to eq(2)

            payload[:disputePDFs].all? do |pdf|
              pdf[:fileName].end_with?('.pdf') &&
                pdf[:fileContents].is_a?(String) &&
                Base64.decode64(pdf[:fileContents]).include?('%PDF')
            end
          end
        ).and_return(true)

        described_class.new(user, submission).call!
      end
    end

    context 'when the downstream call raises' do
      it 're-raises and does not mark submission as submitted' do
        submission = build_submission_with_files(pdf_file_one)

        allow_any_instance_of(described_class)
          .to receive(:perform)
          .with(:post, 'dispute-debt', kind_of(Hash))
          .and_raise(StandardError, 'DMC blew up')

        expect do
          described_class.new(user, submission).call!
        end.to raise_error(StandardError, 'DMC blew up')

        expect(submission.reload).to be_pending
      end
    end
  end

  describe '#sanitize_filename' do
    it 'removes extra dots' do
      submission = build_submission_with_files(pdf_file_one)
      service = described_class.new(user, submission)
      expect(service.send(:sanitize_filename, 'test.file.name.pdf')).to eq('testfilename.pdf')
    end

    it 'replaces colons with underscores' do
      submission = build_submission_with_files(pdf_file_one)
      service = described_class.new(user, submission)
      expect(service.send(:sanitize_filename, 'test:file:name.pdf')).to eq('test_file_name.pdf')
    end

    it 'strips path components' do
      submission = build_submission_with_files(pdf_file_one)
      service = described_class.new(user, submission)
      expect(service.send(:sanitize_filename, '/path/to/file.pdf')).to eq('file.pdf')
    end
  end
end
