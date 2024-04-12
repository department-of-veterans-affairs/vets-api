# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PegaTable, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:uuid) }
    it { is_expected.to validate_presence_of(:veteranfirstname) }
    it { is_expected.to validate_presence_of(:veteranlastname) }
    it { is_expected.to validate_presence_of(:response) }

    context 'custom validations' do
      it 'ensures response contains a valid HTTP status code' do
        # Test case for valid status code (200)
        pega_table = build(:pega_table, :with_valid_response)
        expect(pega_table).to be_valid

        # Test case for invalid status code (400)
        pega_table = build(:pega_table, :with_invalid_response)
        pega_table.valid?
        expect(pega_table.errors[:response]).to include('must contain a valid HTTP status code (200, 403, 500)')

        # Test case for invalid JSON format
        pega_table = build(:pega_table, :with_invalid_json_response)
        pega_table.valid?
        expect(pega_table.errors[:response]).to include('must be a valid JSON format')
      end
    end
  end
end

