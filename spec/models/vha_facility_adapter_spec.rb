# frozen_string_literal: true
require 'rails_helper'

RSpec.describe VHAFacilityAdapter, type: :adapter do
  subject { nil }

  it '#it handles zip-zip4' do
    model = described_class.from_gis(FactoryGirl.build(:vha_gis_record))
    expect(model.address[:physical][:zip]).to eq('97239-2964')
  end

  it '#it handles zip' do
    input = FactoryGirl.build(:vha_gis_record)
    input['attributes']['Zip4'] = ' '
    model = described_class.from_gis(input)
    expect(model.address[:physical][:zip]).to eq('97239')
  end

  it '#it handles null zip4' do
    input = FactoryGirl.build(:vha_gis_record)
    input['attributes']['Zip4'] = nil
    model = described_class.from_gis(input)
    expect(model.address[:physical][:zip]).to eq('97239')
  end

  it '#it handles mh_phone without extension' do
    input = FactoryGirl.build(:vha_gis_record)
    model = described_class.from_gis(input)
    expect(model.phone[:mental_health_clinic]).to eq('5032735187')
  end

  it '#it handles mh_phone with extension' do
    input = FactoryGirl.build(:vha_gis_record)
    input['attributes']['Extension'] = 12_345
    model = described_class.from_gis(input)
    expect(model.phone[:mental_health_clinic]).to eq('5032735187 x 12345')
  end

  it '#it handles empty mh_phone' do
    input = FactoryGirl.build(:vha_gis_record)
    input['attributes']['MHClinicPhone'] = ''
    model = described_class.from_gis(input)
    expect(model.phone[:mental_health_clinic]).to eq('')
  end

  it '#it handles nil mh_phone' do
    input = FactoryGirl.build(:vha_gis_record)
    input['attributes']['MHClinicPhone'] = nil
    model = described_class.from_gis(input)
    expect(model.phone[:mental_health_clinic]).to eq('')
  end

  it '#it handles zero extension' do
    input = FactoryGirl.build(:vha_gis_record)
    input['attributes']['Extension'] = 0
    model = described_class.from_gis(input)
    expect(model.phone[:mental_health_clinic]).to eq('5032735187')
  end

  it '#it handles nil mh_phone' do
    input = FactoryGirl.build(:vha_gis_record)
    input['attributes']['MHClinicPhone'] = nil
    model = described_class.from_gis(input)
    expect(model.phone[:mental_health_clinic]).to eq('')
  end

  it 'filters unapproved services' do
    input = FactoryGirl.build(:vha_gis_record)
    input['attributes']['InfectiousDisease'] = 'YES'
    model = described_class.from_gis(input)
    expect(model.services[:health].length).to eq(2)
  end
end
