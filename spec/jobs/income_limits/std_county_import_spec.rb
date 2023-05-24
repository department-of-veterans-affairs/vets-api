# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe IncomeLimits::StdCountyImport, type: :worker do
  describe '#perform' do
    # rubocop:disable Layout/LineLength
    let(:csv_data) do
      %(ID,NAME,COUNTYNUMBER,DESCRIPTION,STATE_ID,VERSION,CREATED,UPDATED,CREATEDBY,UPDATEDBY\n1,County A,123,Description A,456,1,2/19/2010 8:36:52.057269 AM,3/19/2010 8:36:52.057269 AM,John,Sam)
    end
    # rubocop:enable Layout/LineLength

    before do
      allow_any_instance_of(IncomeLimits::StdCountyImport).to receive(:fetch_csv_data).and_return(csv_data)
    end

    it 'populates gmt thresholds' do
      IncomeLimits::StdCountyImport.new.perform
      expect(StdCounty.find_by(name: 'County A')).not_to be_nil
      expect(StdCounty.find_by(county_number: 123)).not_to be_nil
    end

    context 'when a matching record does not exist' do
      it 'creates a new record' do
        expect do
          described_class.new.perform
        end.to change(StdCounty, :count).by(1)
      end

      it 'sets the attributes correctly' do
        described_class.new.perform
        county = StdCounty.last
        expect(county.name).to eq('County A')
        expect(county.county_number).to eq(123)
        expect(county.description).to eq('Description A')
        expect(county.state_id).to eq(456)
        expect(county.version).to eq(1)
        expect(county.created_by).to eq('John')
        expect(county.updated_by).to eq('Sam')
      end
    end
  end
end
