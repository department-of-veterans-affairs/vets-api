# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe IncomeLimits::StdZipcodeImport, type: :worker do
  describe '#perform' do
    # rubocop:disable Layout/LineLength
    let(:csv_data) do
      %(ID,ZIPCODE,ZIPCLASSIFICATION_ID,PREFERREDZIPPLACE_ID,STATE_ID,COUNTYNUMBER,VERSION,CREATED,UPDATED,CREATEDBY,UPDATEDBY\n1,12345,1,2,3,123,5,2/19/2010 8:36:52.057269 AM,3/19/2010 8:36:52.057269 AM,John,Sam)
    end
    # rubocop:enable Layout/LineLength

    before do
      allow_any_instance_of(IncomeLimits::StdZipcodeImport).to receive(:fetch_csv_data).and_return(csv_data)
    end

    it 'populates zipcodes' do
      skip 'For migration'
      IncomeLimits::StdZipcodeImport.new.perform
      expect(StdZipcode.find_by(zip_code: 12_345)).not_to be_nil
      expect(StdZipcode.find_by(county_number: 123)).not_to be_nil
    end

    context 'when a matching record does exist' do
      it 'creates a new record' do
        expect do
          described_class.new.perform
        end.to change(StdZipcode, :count).by(1)
      end

      it 'sets the attributes correctly' do
        skip 'For migration'
        described_class.new.perform
        zipcode = StdZipcode.last
        expect(zipcode.zip_code).to eq(12_345)
        expect(zipcode.zip_classification_id).to eq(1)
        expect(zipcode.preferred_zip_place_id).to eq(2)
        expect(zipcode.state_id).to eq(3)
        expect(zipcode.county_number).to eq(123)
        expect(zipcode.version).to eq(5)
        expect(zipcode.created_by).to eq('John')
        expect(zipcode.updated_by).to eq('Sam')
      end
    end
  end
end
