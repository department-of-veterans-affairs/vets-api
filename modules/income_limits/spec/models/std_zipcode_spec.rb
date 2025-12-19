# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StdZipcode, type: :model do
  let!(:state) { create(:std_state) }
  let!(:other_state) { create(:std_state) }

  describe '.with_zip_code' do
    let!(:matching_zip) { create(:std_zipcode, zip_code: '12345') }
    let!(:other_zip) { create(:std_zipcode, zip_code: '54321') }

    it 'returns only zipcodes with the requested zip code' do
      result = described_class.with_zip_code('12345')

      expect(result).to contain_exactly(matching_zip)
    end
  end

  describe '.for_state_id' do
    let!(:matching_zip) { create(:std_zipcode, state_id: state.id) }
    let!(:other_zip) { create(:std_zipcode, state_id: other_state.id) }

    it 'returns only zipcodes for the requested state' do
      result = described_class.for_state_id(state.id)

      expect(result).to contain_exactly(matching_zip)
    end
  end

  describe '.for_zip_and_state' do
    let!(:matching_zip) { create(:std_zipcode, zip_code: '60606', state_id: state.id) }
    let!(:different_state) { create(:std_zipcode, zip_code: '60606', state_id: other_state.id) }
    let!(:different_zip) { create(:std_zipcode, zip_code: '10101', state_id: state.id) }

    it 'returns only zipcodes that match both zip and state' do
      result = described_class.for_zip_and_state('60606', state.id)

      expect(result).to contain_exactly(matching_zip)
    end
  end
end
