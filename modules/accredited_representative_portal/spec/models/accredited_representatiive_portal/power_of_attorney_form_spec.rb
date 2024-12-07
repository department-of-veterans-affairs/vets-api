# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe PowerOfAttorneyForm, type: :model do
    describe 'table name' do
      it 'uses custom table name' do
        expect(described_class.table_name).to eq 'ar_power_of_attorney_forms'
      end
    end

    describe 'associations' do
      it 'belongs to power of attorney request' do
        expect(described_class.new).to belong_to(:power_of_attorney_request)
          .with_foreign_key('ar_power_of_attorney_request_id')
      end
    end

    describe 'encryption' do
      it 'has kms key' do
        expect(described_class).to respond_to(:has_kms_key)
      end

      it 'encrypts data' do
        expect(described_class).to respond_to(:has_encrypted)
      end
    end

    describe 'blind indexes' do
      it 'has blind indexes for location fields' do
        expect(described_class.blind_indexes).to include(:city, :state, :zipcode)
      end
    end
  end
end
