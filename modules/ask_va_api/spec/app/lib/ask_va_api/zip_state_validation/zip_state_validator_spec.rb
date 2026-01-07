# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::ZipStateValidation::ZipStateValidator do
  subject(:result) { described_class.call(zip_code:, state_code:) }

  let(:zip_code) { '94107' }
  let(:state_code) { 'CA' }

  let!(:state) { create(:std_state, id: 9_001_001, postal_name: 'CA') }
  let!(:zip) { create(:std_zipcode, id: 8_001_001, zip_code: '94107', state_id: state.id) }

  describe '.call' do
    context 'when zip and state match' do
      it 'returns valid' do
        expect(result.valid).to be(true)
        expect(result.error_code).to be_nil
        expect(result.error_message).to be_nil
      end
    end

    context 'when zip is ZIP+4' do
      let(:zip_code) { '94107-1234' }

      it 'normalizes to 5 digits and returns valid' do
        expect(result.valid).to be(true)
      end
    end

    context 'when zip has whitespace' do
      let(:zip_code) { ' 94107 ' }

      it 'strips whitespace and returns valid' do
        expect(result.valid).to be(true)
      end
    end

    context 'when zip is invalid format' do
      let(:zip_code) { '9410' }

      it 'returns INVALID_ZIP' do
        expect(result.valid).to be(false)
        expect(result.error_code).to eq('INVALID_ZIP')
      end
    end

    context 'when state_code is invalid format' do
      let(:state_code) { 'CAL' }

      it 'returns STATE_NOT_FOUND (format)' do
        expect(result.valid).to be(false)
        expect(result.error_code).to eq('STATE_NOT_FOUND')
      end
    end

    context 'when state_code is lowercase or has whitespace' do
      let(:state_code) { ' ca ' }

      it 'normalizes and returns valid' do
        expect(result.valid).to be(true)
      end
    end

    context 'when state is not found in std_states' do
      let(:state_code) { 'ZZ' }

      it 'returns STATE_NOT_FOUND (not in db)' do
        expect(result.valid).to be(false)
        expect(result.error_code).to eq('STATE_NOT_FOUND')
      end
    end

    context 'when zip does not exist in std_zipcodes' do
      let(:zip_code) { '00000' }

      it 'returns ZIP_NOT_FOUND' do
        expect(result.valid).to be(false)
        expect(result.error_code).to eq('ZIP_NOT_FOUND')
      end
    end

    context 'when zip exists but belongs to a different state' do
      let!(:other_state) { create(:std_state, id: 9_001_002, postal_name: 'NV') }
      let!(:other_zip) { create(:std_zipcode, id: 8_001_002, zip_code: '99999', state_id: other_state.id) }
      let(:zip_code) { '99999' }
      let(:state_code) { 'CA' }

      it 'returns ZIP_STATE_MISMATCH' do
        expect(result.valid).to be(false)
        expect(result.error_code).to eq('ZIP_STATE_MISMATCH')
      end
    end
  end
end
