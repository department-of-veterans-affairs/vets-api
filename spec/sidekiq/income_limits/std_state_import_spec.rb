# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe IncomeLimits::StdStateImport, type: :worker do
  describe '#perform' do
    # rubocop:disable Layout/LineLength
    let(:csv_data) do
      %(ID,NAME,POSTALNAME,FIPSCODE,COUNTRY_ID,VERSION,CREATED,UPDATED,CREATEDBY,UPDATEDBY\n1,Maine,Sample County,123,2,1,2/19/2010 8:36:52.057269 AM,3/19/2010 8:36:52.057269 AM,John,Sam)
    end
    # rubocop:enable Layout/LineLength

    before do
      allow_any_instance_of(IncomeLimits::StdStateImport).to receive(:fetch_csv_data).and_return(csv_data)
    end

    it 'populates states' do
      IncomeLimits::StdStateImport.new.perform
      expect(StdState.find_by(name: 'Maine')).not_to be_nil
      expect(StdState.find_by(fips_code: 123)).not_to be_nil
    end

    it 'creates a new StdState record' do
      expect do
        described_class.new.perform
      end.to change(StdState, :count).by(1)
    end

    it 'sets the attributes correctly' do
      described_class.new.perform
      state = StdState.last
      expect(state.name).to eq('Maine')
      expect(state.postal_name).to eq('Sample County')
      expect(state.fips_code).to eq(123)
      expect(state.country_id).to eq(2)
      expect(state.version).to eq(1)
    end
  end
end
