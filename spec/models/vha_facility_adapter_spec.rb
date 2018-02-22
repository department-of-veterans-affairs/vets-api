# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VHAFacilityAdapter, type: :adapter do
  subject { nil }

  it '#it handles zip-zip4' do
    model = described_class.from_gis(FactoryBot.build(:vha_gis_record))
    expect(model.address[:physical][:zip]).to eq('97239-2964')
  end

  it '#it handles zip' do
    input = FactoryBot.build(:vha_gis_record)
    input['attributes']['Zip4'] = ' '
    model = described_class.from_gis(input)
    expect(model.address[:physical][:zip]).to eq('97239')
  end

  it '#it handles null zip4' do
    input = FactoryBot.build(:vha_gis_record)
    input['attributes']['Zip4'] = nil
    model = described_class.from_gis(input)
    expect(model.address[:physical][:zip]).to eq('97239')
  end

  context 'with MHClinicPhone attribute' do
    it '#it handles mh_clinic_phone without extension' do
      input = FactoryBot.build(:vha_gis_record)
      model = described_class.from_gis(input)
      expect(model.phone[:mental_health_clinic]).to eq('5032735187')
    end

    it '#it handles mh_clinic_phone with extension' do
      input = FactoryBot.build(:vha_gis_record)
      input['attributes']['Extension'] = 12_345
      model = described_class.from_gis(input)
      expect(model.phone[:mental_health_clinic]).to eq('5032735187 x 12345')
    end

    it '#it handles empty mh_clinic_phone' do
      input = FactoryBot.build(:vha_gis_record)
      input['attributes']['MHClinicPhone'] = ''
      model = described_class.from_gis(input)
      expect(model.phone[:mental_health_clinic]).to eq('')
    end

    it '#it handles nil mh_clinic_phone' do
      input = FactoryBot.build(:vha_gis_record)
      input['attributes']['MHClinicPhone'] = nil
      model = described_class.from_gis(input)
      expect(model.phone[:mental_health_clinic]).to eq('')
    end

    it '#it handles zero extension' do
      input = FactoryBot.build(:vha_gis_record)
      input['attributes']['Extension'] = 0
      model = described_class.from_gis(input)
      expect(model.phone[:mental_health_clinic]).to eq('5032735187')
    end

    it '#it handles nil mh_clinic_phone' do
      input = FactoryBot.build(:vha_gis_record)
      input['attributes']['MHClinicPhone'] = nil
      model = described_class.from_gis(input)
      expect(model.phone[:mental_health_clinic]).to eq('')
    end
  end

  context 'with MHPhone attribute' do
    before(:each) do
      @input = FactoryBot.build(:vha_gis_record_v3)
    end

    it '#it handles mh_phone without extension' do
      model = described_class.from_gis(@input)
      expect(model.phone[:mental_health_clinic]).to eq('5032735187')
    end

    it '#it handles mh_phone with extension' do
      @input['attributes']['Extension'] = 12_345
      model = described_class.from_gis(@input)
      expect(model.phone[:mental_health_clinic]).to eq('5032735187 x 12345')
    end

    it '#it handles empty mh_phone' do
      @input['attributes']['MHPhone'] = ''
      model = described_class.from_gis(@input)
      expect(model.phone[:mental_health_clinic]).to eq('')
    end

    it '#it handles nil mh_phone' do
      @input['attributes']['MHPhone'] = nil
      model = described_class.from_gis(@input)
      expect(model.phone[:mental_health_clinic]).to eq('')
    end

    it '#it handles zero extension' do
      @input['attributes']['Extension'] = 0
      model = described_class.from_gis(@input)
      expect(model.phone[:mental_health_clinic]).to eq('5032735187')
    end
  end

  it 'filters unapproved services' do
    input = FactoryBot.build(:vha_gis_record)
    input['attributes']['InfectiousDisease'] = 'YES'
    model = described_class.from_gis(input)
    expect(model.services[:health].length).to eq(2)
  end

  it 'populates satisfaction date field' do
    FactoryBot.build(:access_satisfaction).save
    input = FactoryBot.build(:vha_gis_record)
    model = described_class.from_gis(input)
    expect(model.feedback[:health]['effective_date']).to eq('2017-03-24')
  end

  it 'populates satisfaction data' do
    FactoryBot.build(:access_satisfaction).save
    input = FactoryBot.build(:vha_gis_record)
    model = described_class.from_gis(input)
    expect(model.feedback[:health]['primary_care_urgent']).to eq(0.72)
  end

  it 'populates wait time data' do
    FactoryBot.build(:access_wait_time).save
    input = FactoryBot.build(:vha_gis_record)
    model = described_class.from_gis(input)
    expect(model.access[:health]['primary_care']).to eq('new' => 35.0, 'established' => 9.0)
  end
end
