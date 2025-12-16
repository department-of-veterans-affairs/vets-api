# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/digital_dispute_submission_service'

RSpec.describe DebtsApi::V0::DigitalDisputeSubmissionService do
  let(:pdf_file_one) do
    fixture_file_upload('spec/fixtures/pdf_fill/686C-674/tester.pdf', 'application/pdf')
  end
  let(:pdf_file_two) do
    fixture_file_upload('spec/fixtures/pdf_fill/686C-674-V2/tester.pdf', 'application/pdf')
  end
  let(:image_file) do
    fixture_file_upload('doctors-note.png', 'image/png')
  end
  let(:user) { build(:user, :loa3) }

  describe '#call' do
    context 'email notifications' do
      let(:user) { create(:user, :loa3, email: 'test@example.com') }

      before do
        allow_any_instance_of(described_class).to receive(:send_to_dmc)
      end

      context 'when digital_dispute_email_notifications is enabled' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:digital_dispute_email_notifications)
            .and_return(true)
        end

        it 'schedules submission email after successful DMC submission' do
          expect(DebtsApi::V0::Form5655::SendConfirmationEmailJob).to receive(:perform_in).with(5.minutes, anything)

          service = described_class.new(user, [pdf_file_one])
          service.call
        end
      end

      context 'when digital_dispute_email_notifications is disabled' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:digital_dispute_email_notifications)
            .and_return(false)
        end

        it 'does not schedule submission email' do
          expect(DebtsApi::V0::Form5655::SendConfirmationEmailJob).not_to receive(:perform_in)

          service = described_class.new(user, [pdf_file_one])
          service.call
        end
      end
    end

    context 'with valid files' do
      it 'sends expected payload with correct structure' do
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

        service = described_class.new(user, [pdf_file_one])
        result = service.call

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Digital dispute submission received successfully')
      end

      it 'returns success result for multiple PDF files' do
        expect_any_instance_of(described_class).to receive(:perform).with(
          :post,
          'dispute-debt',
          satisfy do |payload|
            next false unless payload[:fileNumber] == user.ssn
            next false unless payload[:disputePDFs].size == 2

            payload[:disputePDFs].all? do |pdf|
              pdf[:fileName].end_with?('.pdf') &&
                pdf[:fileContents].is_a?(String) &&
                Base64.decode64(pdf[:fileContents]).include?('%PDF')
            end
          end
        )

        service = described_class.new(user, [pdf_file_one, pdf_file_two])
        result = service.call

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Digital dispute submission received successfully')
      end
    end

    context 'with invalid input' do
      it 'returns failure when no files provided' do
        service = described_class.new(user, nil)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors][:base]).to include('Files at least one file is required')
      end

      it 'returns failure when empty array provided' do
        service = described_class.new(user, [])
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors][:base]).to include('Files at least one file is required')
      end

      it 'returns failure for non-PDF files' do
        service = described_class.new(user, [image_file])
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors][:base]).to include('Files File 1 must be a PDF')
      end

      it 'returns failure for mixed file types' do
        service = described_class.new(user, [pdf_file_one, image_file])
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors][:base]).to include('Files File 2 must be a PDF')
      end

      it 'returns failure for oversized files' do
        submission = build(:debts_api_digital_dispute_submission)
        allow(submission.files.first.blob).to receive(:byte_size).and_return(2.megabytes)

        submission.valid?

        expect(submission.errors[:files]).to include('File 1 is too large (maximum is 1MB)')
      end

      it 'returns multiple errors for multiple invalid files' do
        allow(pdf_file_one).to receive(:size).and_return(2.megabytes)

        service = described_class.new(user, [pdf_file_one, image_file])
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors][:base]).to include('Files File 2 must be a PDF')
      end
    end

    context 'when unexpected error occurs' do
      it 'returns generic failure result' do
        VCR.use_cassette('bgs/people_service/person_data') do
          allow_any_instance_of(described_class).to receive(:send_to_dmc)
            .and_raise(StandardError.new('Unexpected error'))

          expect(Rails.logger).to receive(:error).with('DigitalDisputeSubmission error_message: Unexpected error')

          metadata = { disputes: [{ composite_debt_id: 12 }, { composite_debt_id: 34 }, { composite_debt_id: 56 }] }
          service = described_class.new(user, [pdf_file_one], metadata)
          result = service.call

          expect(result[:success]).to be false
          expect(result[:errors][:base]).to include('An error occurred processing your submission')
        end
      end
    end

    context 'duplicate prevention' do
      let(:metadata) do
        {
          disputes: [
            {
              composite_debt_id: 'ABC123',
              debt_type: 'overpayment',
              dispute_reason: 'incorrect_amount'
            }
          ]
        }
      end

      before do
        # Create existing submission with same debt
        create(:debts_api_digital_dispute_submission,
               user_uuid: user.uuid,
               user_account: user.user_account,
               debt_identifiers: ['ABC123'],
               state: :submitted)

        allow_any_instance_of(described_class).to receive(:send_to_dmc)
          .and_return(OpenStruct.new(body: {}))
      end

      context 'when digital_dispute_duplicate_prevention is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:digital_dispute_duplicate_prevention).and_return(true)
        end

        it 'prevents duplicate submissions' do
          service = described_class.new(user, [pdf_file_one], metadata)
          result = service.call

          expect(result[:success]).to be false
          expect(result[:error_type]).to eq('duplicate_dispute')
          expect(result[:errors][:base]).to include('A dispute for these debts has already been submitted')
        end
      end

      context 'when digital_dispute_duplicate_prevention is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:digital_dispute_duplicate_prevention).and_return(false)
        end

        it 'allows duplicate submissions' do
          service = described_class.new(user, [pdf_file_one], metadata)
          result = service.call

          expect(result[:success]).to be true
          expect(result[:message]).to eq('Digital dispute submission received successfully')
        end
      end
    end
  end

  describe '#sanitize_filename' do
    it 'removes extra dots from filename' do
      service = described_class.new(user, [pdf_file_one])
      result = service.send(:sanitize_filename, 'test.file.name.pdf')

      expect(result).to eq('testfilename.pdf')
    end

    it 'replaces colons with underscores' do
      service = described_class.new(user, [pdf_file_one])
      result = service.send(:sanitize_filename, 'test:file:name.pdf')

      expect(result).to eq('test_file_name.pdf')
    end

    it 'handles filenames with directory paths' do
      service = described_class.new(user, [pdf_file_one])
      result = service.send(:sanitize_filename, '/path/to/file.pdf')

      expect(result).to eq('file.pdf')
    end
  end
end
