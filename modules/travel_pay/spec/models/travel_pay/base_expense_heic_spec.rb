# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::BaseExpense, type: :model do
  describe 'HEIC to JPG conversion' do
    subject { described_class.new(valid_attributes) }

    let(:valid_attributes) do
      {
        purchase_date: 1.day.ago,
        description: 'Test expense with receipt',
        cost_requested: 50.00
      }
    end

    let(:test_image_base64) do
      # Use real HEIC fixture for testing
      fixture_path = Rails.root.join('modules', 'travel_pay', 'spec', 'fixtures', 'pixel-working.heic')
      binary_data = File.binread(fixture_path)
      Base64.strict_encode64(binary_data)
    end

    before do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_heic_conversion).and_return(true)
    end

    describe '#receipt= with HEIC content' do
      context 'when receipt has image/heic content type' do
        let(:heic_receipt) do
          {
            'file_name' => 'receipt.heic',
            'content_type' => 'image/heic',
            'file_data' => test_image_base64,
            'length' => '500'
          }
        end

        it 'converts the receipt to JPG format' do
          subject.receipt = heic_receipt

          expect(subject.receipt).to be_present
          expect(subject.receipt['content_type']).to eq('image/jpeg')
          expect(subject.receipt[:content_type]).to eq('image/jpeg')
        end

        it 'updates the file name extension' do
          subject.receipt = heic_receipt

          expect(subject.receipt['file_name']).to eq('receipt.jpg')
          expect(subject.receipt[:file_name]).to eq('receipt.jpg')
        end

        it 'maintains base64 encoded file data' do
          subject.receipt = heic_receipt

          file_data = subject.receipt['file_data'] || subject.receipt[:file_data]
          expect(file_data).to be_present
          expect { Base64.strict_decode64(file_data) }.not_to raise_error
        end

        it 'updates the length to reflect new file size' do
          subject.receipt = heic_receipt

          new_length = (subject.receipt['length'] || subject.receipt[:length]).to_i
          expect(new_length).to be_positive
          # Length may change during conversion
        end
      end

      context 'when receipt has image/heif content type' do
        let(:heif_receipt) do
          {
            'file_name' => 'photo.heif',
            'content_type' => 'image/heif',
            'file_data' => test_image_base64,
            'length' => '500'
          }
        end

        it 'converts the receipt to JPG format' do
          subject.receipt = heif_receipt

          expect(subject.receipt['content_type']).to eq('image/jpeg')
        end

        it 'updates the file name extension' do
          subject.receipt = heif_receipt

          expect(subject.receipt['file_name']).to eq('photo.jpg')
        end
      end

      context 'when receipt uses symbol keys' do
        let(:heic_receipt_symbols) do
          {
            file_name: 'receipt.HEIC',
            content_type: 'image/heic',
            file_data: test_image_base64,
            length: '500'
          }
        end

        it 'handles symbol keys correctly' do
          subject.receipt = heic_receipt_symbols

          expect(subject.receipt[:content_type]).to eq('image/jpeg')
          expect(subject.receipt[:file_name]).to eq('receipt.jpg')
        end
      end

      context 'when content type is case-insensitive' do
        let(:uppercase_heic_receipt) do
          {
            'file_name' => 'receipt.HEIC',
            'content_type' => 'IMAGE/HEIC',
            'file_data' => test_image_base64,
            'length' => '500'
          }
        end

        it 'detects HEIC regardless of case' do
          subject.receipt = uppercase_heic_receipt

          expect(subject.receipt['content_type']).to eq('image/jpeg')
        end
      end

      context 'when feature flag is disabled' do
        let(:heic_receipt) do
          {
            'file_name' => 'receipt.heic',
            'content_type' => 'image/heic',
            'file_data' => test_image_base64,
            'length' => '500'
          }
        end

        before do
          allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_heic_conversion).and_return(false)
        end

        it 'does not convert HEIC receipts when flag is disabled' do
          subject.receipt = heic_receipt

          expect(subject.receipt).to eq(heic_receipt)
          expect(subject.receipt['content_type']).to eq('image/heic')
          expect(subject.receipt['file_name']).to eq('receipt.heic')
        end
      end

      context 'when receipt is not HEIC format' do
        let(:jpeg_receipt) do
          {
            'file_name' => 'receipt.jpg',
            'content_type' => 'image/jpeg',
            'file_data' => test_image_base64,
            'length' => '500'
          }
        end

        it 'does not modify non-HEIC receipts' do
          subject.receipt = jpeg_receipt

          expect(subject.receipt).to eq(jpeg_receipt)
          expect(subject.receipt['content_type']).to eq('image/jpeg')
          expect(subject.receipt['file_name']).to eq('receipt.jpg')
        end
      end

      context 'when receipt is a PDF' do
        let(:pdf_receipt) do
          {
            'file_name' => 'receipt.pdf',
            'content_type' => 'application/pdf',
            'file_data' => test_image_base64,
            'length' => '1000'
          }
        end

        it 'does not modify PDF receipts' do
          subject.receipt = pdf_receipt

          expect(subject.receipt).to eq(pdf_receipt)
          expect(subject.receipt['content_type']).to eq('application/pdf')
        end
      end

      context 'when conversion fails' do
        let(:invalid_heic_receipt) do
          {
            'file_name' => 'receipt.heic',
            'content_type' => 'image/heic',
            'file_data' => 'invalid-base64-data!!!',
            'length' => '500'
          }
        end

        it 'falls back to original data and logs error' do
          allow(Rails.logger).to receive(:info)
          expect(Rails.logger).to receive(:error).with(/Error converting HEIC receipt/)

          subject.receipt = invalid_heic_receipt

          # Should fall back to original data
          expect(subject.receipt).to eq(invalid_heic_receipt)
          expect(subject.receipt['content_type']).to eq('image/heic')
        end
      end

      context 'when receipt is nil' do
        it 'handles nil receipt gracefully' do
          subject.receipt = nil

          expect(subject.receipt).to be_nil
        end
      end

      context 'when receipt is an empty hash' do
        it 'handles empty hash gracefully' do
          subject.receipt = {}

          expect(subject.receipt).to be_nil
        end
      end
    end

    describe 'integration with to_service_params' do
      context 'when expense has HEIC receipt' do
        let(:heic_receipt) do
          {
            'file_name' => 'receipt.heic',
            'content_type' => 'image/heic',
            'file_data' => test_image_base64,
            'length' => '500'
          }
        end

        it 'includes converted receipt in service params' do
          subject.receipt = heic_receipt
          params = subject.to_service_params

          expect(params['receipt']).to be_present
          expect(params['receipt']['contentType']).to eq('image/jpeg')
          expect(params['receipt']['fileName']).to eq('receipt.jpg')
        end
      end
    end
  end
end
