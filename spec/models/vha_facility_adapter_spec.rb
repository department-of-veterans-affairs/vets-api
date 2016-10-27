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
end
