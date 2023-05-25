# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe IncomeLimits::GmtThresholdsImport, type: :worker do
  describe '#perform' do
    # rubocop:disable Layout/LineLength
    let(:csv_data) do
      %(ID,EFFECTIVEYEAR,STATENAME,COUNTYNAME,FIPS,TRHD1,TRHD2,TRHD3,TRHD4,TRHD5,TRHD6,TRHD7,TRHD8,MSA,MSANAME,VERSION,CREATED,UPDATED,CREATEDBY,UPDATEDBY\n1,2023,State A,County X,123,100,200,300,400,500,600,700,800,900,MSA A,1,2/19/2010 8:36:52.057269 AM,3/19/2010 8:36:52.057269 AM,John,Sam)
    end
    # rubocop:enable Layout/LineLength

    before do
      allow_any_instance_of(IncomeLimits::GmtThresholdsImport).to receive(:fetch_csv_data).and_return(csv_data)
    end

    it 'populates gmt thresholds' do
      IncomeLimits::GmtThresholdsImport.new.perform
      expect(GmtThreshold.find_by(effective_year: 2023)).not_to be_nil
      expect(GmtThreshold.find_by(county_name: 'County X')).not_to be_nil
    end

    it 'creates a new StdState record' do
      expect do
        described_class.new.perform
      end.to change(GmtThreshold, :count).by(1)
    end

    it 'sets the attributes correctly' do
      described_class.new.perform
      threshold = GmtThreshold.last
      expect(threshold.effective_year).to eq(2023)
      expect(threshold.state_name).to eq('State A')
      expect(threshold.county_name).to eq('County X')
      expect(threshold.fips).to eq(123)
      expect(threshold.trhd1).to eq(100)
      expect(threshold.trhd2).to eq(200)
      expect(threshold.trhd3).to eq(300)
      expect(threshold.trhd4).to eq(400)
      expect(threshold.trhd5).to eq(500)
      expect(threshold.trhd6).to eq(600)
      expect(threshold.trhd7).to eq(700)
      expect(threshold.trhd8).to eq(800)
      expect(threshold.msa).to eq(900)
      expect(threshold.msa_name).to eq('MSA A')
      expect(threshold.version).to eq(1)
      expect(threshold.created_by).to eq('John')
      expect(threshold.updated_by).to eq('Sam')
    end
  end
end
