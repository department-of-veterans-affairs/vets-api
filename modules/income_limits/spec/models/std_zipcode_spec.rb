# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StdZipcode, type: :model do
  let!(:state) { create(:std_state, id: 9_001_001, postal_name: 'NC') }
  let!(:other_state) { create(:std_state, id: 9_001_002, postal_name: 'VA') }

  describe '.with_zip_code' do
    let!(:matching_zip) { create(:std_zipcode, id: 8_001_001, zip_code: '99991') }
    let!(:other_zip) { create(:std_zipcode, id: 8_001_002, zip_code: '88882') }

    it 'returns only zipcodes with the requested zip code' do
      result = described_class.with_zip_code('99991')

      expect(result).to contain_exactly(matching_zip)
    end
  end

  describe '.for_state_id' do
    let!(:matching_zip) { create(:std_zipcode, id: 8_002_001, state_id: state.id) }
    let!(:other_zip) { create(:std_zipcode, id: 8_002_002, state_id: other_state.id) }

    it 'returns only zipcodes for the requested state' do
      result = described_class.for_state_id(state.id)

      expect(result).to contain_exactly(matching_zip)
    end
  end

  describe '.for_zip_and_state' do
    let!(:matching_zip) do
      create(:std_zipcode, id: 8_003_001, zip_code: '60606', state_id: state.id)
    end
    let!(:different_state) do
      create(:std_zipcode, id: 8_003_002, zip_code: '60606', state_id: other_state.id)
    end
    let!(:different_zip) do
      create(:std_zipcode, id: 8_003_003, zip_code: '10101', state_id: state.id)
    end

    it 'returns only zipcodes that match both zip and state' do
      result = described_class.for_zip_and_state('60606', state.id)

      expect(result).to contain_exactly(matching_zip)
    end
  end
end
