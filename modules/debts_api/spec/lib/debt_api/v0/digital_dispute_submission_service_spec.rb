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
    context 'with valid files' do
      it 'sends expected payload with correct structure' do
        expect_any_instance_of(described_class).to receive(:perform).with(
          :post,
          '/dispute-debt',
          satisfy do |payload|
            expect(payload[:file_number]).to eq(user.ssn)

            expect(payload[:dispute_pdfs].size).to eq(1)
            pdf = payload[:dispute_pdfs].first

            expect(pdf[:file_name]).to eq('tester.pdf')
            expect(pdf[:file_contents]).to be_a(String)
            expect(Base64.decode64(pdf[:file_contents])).to include('%PDF')

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
          '/dispute-debt',
          satisfy do |payload|
            expect(payload[:file_number]).to eq(user.ssn) # Or however it's derived

            expect(payload[:dispute_pdfs].size).to eq(2)

            payload[:dispute_pdfs].each do |pdf|
              expect(pdf[:file_name]).to end_with('.pdf')
              expect(pdf[:file_contents]).to be_a(String)
              expect(Base64.decode64(pdf[:file_contents])).to include('%PDF')
            end

            true
          end
        ).and_return(true)

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
        expect(result[:errors][:files]).to include('at least one file is required')
      end

      it 'returns failure when empty array provided' do
        service = described_class.new(user, [])
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors][:files]).to include('at least one file is required')
      end

      it 'returns failure for non-PDF files' do
        service = described_class.new(user, [image_file])
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors][:files]).to include('File 1 must be a PDF')
      end

      it 'returns failure for mixed file types' do
        service = described_class.new(user, [pdf_file_one, image_file])
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors][:files]).to include('File 2 must be a PDF')
      end

      it 'returns failure for oversized files' do
        allow(pdf_file_one).to receive(:size).and_return(2.megabytes)

        service = described_class.new(user, [pdf_file_one])
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors][:files]).to include('File 1 is too large (maximum is 1MB)')
      end

      it 'returns multiple errors for multiple invalid files' do
        allow(pdf_file_one).to receive(:size).and_return(2.megabytes)

        service = described_class.new(user, [pdf_file_one, image_file])
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors][:files]).to include('File 1 is too large (maximum is 1MB)')
        expect(result[:errors][:files]).to include('File 2 must be a PDF')
      end
    end

    context 'when unexpected error occurs' do
      it 'returns generic failure result' do
        allow_any_instance_of(described_class)
          .to receive(:validate_files_present)
          .and_raise(StandardError.new('Unexpected error'))

        service = described_class.new(user, [pdf_file_one])
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors][:base]).to include('An error occurred processing your submission')
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
