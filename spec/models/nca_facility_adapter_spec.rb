# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NCAFacilityAdapter, type: :adapter do
  subject { nil }

  context 'with v1-style NCA record' do
    before(:each) do
      @model = described_class.from_gis(FactoryBot.build(:nca_gis_record_v1))
    end

    it 'adapts base attributes' do
      expect(@model.unique_id).to eq('894')
      expect(@model.name).to eq('Fort Snelling National Cemetery')
      expect(@model.website).to eq('http://www.cem.va.gov/cems/nchp/ftsnelling.asp')
      expect(@model.lat).to eq(44.864600563324544)
      expect(@model.long).to eq(-93.222882218996432)
    end

    it 'adapts physical address attributes' do
      expect(@model.address[:physical]['address_1']).to eq('7601 34th Ave S')
      expect(@model.address[:physical]['address_2']).to eq('')
      expect(@model.address[:physical]['city']).to eq('Minneapolis')
      expect(@model.address[:physical]['state']).to eq('MN')
      expect(@model.address[:physical]['zip']).to eq('55450-1199')
    end

    it 'adapts mailing address attributes' do
      expect(@model.address[:mailing]['address_1']).to eq('7601 34th Ave S')
      expect(@model.address[:mailing]['address_2']).to eq('')
      expect(@model.address[:mailing]['city']).to eq('Minneapolis')
      expect(@model.address[:mailing]['state']).to eq('MN')
      expect(@model.address[:mailing]['zip']).to eq('55450-1199')
    end

    it 'adapts phone attributes' do
      expect(@model.phone['main']).to eq('612-726-1127')
      expect(@model.phone['fax']).to eq('612-725-2059')
    end

    it 'adapts hours attributes' do
      %w[Monday Tuesday Wednesday Thursday Friday].each do |d|
        expect(@model.hours[d]).to eq('7:30am - 5:00pm')
      end
      %w[Saturday Sunday].each do |d|
        expect(@model.hours[d]).to eq('8:00am - 5:00pm')
      end
    end
  end

  context 'with v2-style NCA record' do
    before(:each) do
      @model = described_class.from_gis(FactoryBot.build(:nca_gis_record_v2))
    end

    it 'adapts base attributes' do
      expect(@model.unique_id).to eq('894')
      expect(@model.name).to eq('Fort Snelling National Cemetery')
      expect(@model.website).to eq('http://www.cem.va.gov/cems/nchp/ftsnelling.asp')
      expect(@model.lat).to eq(44.864600563324544)
      expect(@model.long).to eq(-93.222882218996432)
    end

    it 'adapts physical address attributes' do
      expect(@model.address[:physical]['address_1']).to eq('7601 34th Ave S')
      expect(@model.address[:physical]['address_2']).to be_nil
      expect(@model.address[:physical]['city']).to eq('Minneapolis')
      expect(@model.address[:physical]['state']).to eq('MN')
      expect(@model.address[:physical]['zip']).to eq('55450-1199')
    end

    it 'adapts mailing address attributes' do
      expect(@model.address[:mailing]['address_1']).to eq('7601 34th Ave S')
      expect(@model.address[:mailing]['address_2']).to be_nil
      expect(@model.address[:mailing]['city']).to eq('Minneapolis')
      expect(@model.address[:mailing]['state']).to eq('MN')
      expect(@model.address[:mailing]['zip']).to eq('55450-1199')
    end

    it 'adapts phone attributes' do
      expect(@model.phone['main']).to eq('612-726-1127')
      expect(@model.phone['fax']).to eq('612-725-2059')
    end

    it 'adapts hours attributes' do
      %w[Monday Tuesday Wednesday Thursday Friday].each do |d|
        expect(@model.hours[d]).to eq('7:30am - 5:00pm')
      end
      %w[Saturday Sunday].each do |d|
        expect(@model.hours[d]).to eq('8:00am - 5:00pm')
      end
    end
  end
end
