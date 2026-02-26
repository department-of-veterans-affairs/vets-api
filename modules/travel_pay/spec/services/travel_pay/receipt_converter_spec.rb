# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::ReceiptConverter do
  subject(:converter) { described_class.new(user) }

  let(:user) { build(:user) }

  let(:test_image_base64) do
    fixture_path = Rails.root.join('modules', 'travel_pay', 'spec', 'fixtures', 'pixel-working.heic')
    Base64.strict_encode64(File.binread(fixture_path))
  end

  before do
    allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_heic_conversion, user).and_return(true)
  end

  describe '#convert_if_heic' do
    context 'when params contain a HEIC receipt' do
      let(:params) do
        {
          'claimId' => '123',
          'expenseType' => 'parking',
          'expenseReceipt' => {
            'fileName' => 'receipt.heic',
            'contentType' => 'image/heic',
            'fileData' => test_image_base64,
            'length' => '500'
          }
        }
      end

      it 'converts the receipt to JPG and preserves other params' do
        result = converter.convert_if_heic(params)
        receipt = result['expenseReceipt']

        expect(receipt['contentType']).to eq('image/jpeg')
        expect(receipt['fileName']).to eq('receipt.jpg')
        expect(receipt['length'].to_i).to be_positive
        expect(receipt['fileData']).to be_present
        expect { Base64.strict_decode64(receipt['fileData']) }.not_to raise_error
        expect(result['claimId']).to eq('123')
        expect(result['expenseType']).to eq('parking')
      end

      it 'does not mutate the original params' do
        original_content_type = params['expenseReceipt']['contentType']
        converter.convert_if_heic(params)

        expect(params['expenseReceipt']['contentType']).to eq(original_content_type)
      end
    end

    context 'when params contain a HEIF receipt' do
      let(:params) do
        {
          'expenseReceipt' => {
            'fileName' => 'photo.heif',
            'contentType' => 'image/heif',
            'fileData' => test_image_base64,
            'length' => '500'
          }
        }
      end

      it 'converts HEIF to JPG' do
        result = converter.convert_if_heic(params)

        expect(result['expenseReceipt']['contentType']).to eq('image/jpeg')
        expect(result['expenseReceipt']['fileName']).to eq('photo.jpg')
      end
    end

    context 'when content type casing varies' do
      let(:params) do
        {
          'expenseReceipt' => {
            'fileName' => 'receipt.HEIC',
            'contentType' => 'IMAGE/HEIC',
            'fileData' => test_image_base64,
            'length' => '500'
          }
        }
      end

      it 'detects HEIC regardless of case' do
        result = converter.convert_if_heic(params)

        expect(result['expenseReceipt']['contentType']).to eq('image/jpeg')
      end
    end

    context 'when receipt is not HEIC/HEIF' do
      it 'returns params unchanged for JPEG' do
        params = { 'expenseReceipt' => { 'fileName' => 'receipt.jpg', 'contentType' => 'image/jpeg',
                                         'fileData' => test_image_base64, 'length' => '500' } }
        expect(converter.convert_if_heic(params)).to eq(params)
      end

      it 'returns params unchanged for PDF' do
        params = { 'expenseReceipt' => { 'fileName' => 'receipt.pdf', 'contentType' => 'application/pdf',
                                         'fileData' => 'some-data', 'length' => '1000' } }
        expect(converter.convert_if_heic(params)).to eq(params)
      end
    end

    context 'when no receipt is present' do
      let(:params) { { 'claimId' => '123', 'expenseType' => 'parking' } }

      it 'returns params unchanged' do
        result = converter.convert_if_heic(params)

        expect(result).to eq(params)
      end
    end

    context 'when conversion fails' do
      let(:params) do
        {
          'expenseReceipt' => {
            'fileName' => 'receipt.heic',
            'contentType' => 'image/heic',
            'fileData' => 'invalid-base64-data!!!',
            'length' => '500'
          }
        }
      end

      it 'raises UnprocessableEntity and logs the error' do
        expect(Rails.logger).to receive(:error).with(/HEIC conversion failed/)

        expect { converter.convert_if_heic(params) }
          .to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_heic_conversion, user).and_return(false)
      end

      let(:heic_params) do
        {
          'expenseReceipt' => {
            'fileName' => 'receipt.heic',
            'contentType' => 'image/heic',
            'fileData' => test_image_base64,
            'length' => '500'
          }
        }
      end

      let(:jpeg_params) do
        {
          'expenseReceipt' => {
            'fileName' => 'receipt.jpg',
            'contentType' => 'image/jpeg',
            'fileData' => test_image_base64,
            'length' => '500'
          }
        }
      end

      it 'raises UnprocessableEntity for HEIC receipts' do
        expect { converter.convert_if_heic(heic_params) }
          .to raise_error(Common::Exceptions::UnprocessableEntity)
      end

      it 'returns params unchanged for non-HEIC receipts' do
        expect(converter.convert_if_heic(jpeg_params)).to eq(jpeg_params)
      end
    end
  end
end
