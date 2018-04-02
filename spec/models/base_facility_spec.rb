# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BaseFacility, type: :model do
  let(:bbox) { [-73.401, 40.685, -77.36, 43.03] }
  let(:services) { nil }
  let(:va_facilities) { VAFacility.query(bbox: bbox, type: type, services: services) }
  let(:va_facility) { va_facilities.first }
  let(:nca_facility) { Facilities::NCAFacility.create(va_facility.attributes.except(:facility_type)) }
  let(:vba_facility) { Facilities::VBAFacility.create(va_facility.attributes.except(:facility_type)) }
  let(:vc_facility) { Facilities::VCFacility.create(va_facility.attributes.except(:facility_type)) }
  let(:vha_facility) { Facilities::VHAFacility.create(va_facility.attributes.except(:facility_type)) }

  describe 'VCFacility' do
    let(:type) { VAFacility::VET_CENTER }
    it 'should save and retrieve all attributes and they should match the original object' do
      VCR.use_cassette('facilities/va/ny_vetcenter') do
        va_facility.attributes.each_key do |attr|
          original = va_facility.send(attr)
          original.deep_stringify_keys! if original.is_a?(Hash)
          expect(vc_facility[attr]).to eq(original)
        end
      end
    end
  end

  describe 'VHAFacility' do
    let(:type) { VAFacility::HEALTH }
    it 'should save and retrieve all attributes and they should match the original object' do
      VCR.use_cassette('facilities/va/ny_health') do
        va_facility.attributes.each_key do |attr|
          original = va_facility.send(attr)
          original.deep_stringify_keys! if original.is_a?(Hash)
          expect(vha_facility[attr]).to eq(original)
        end
      end
    end
  end

  describe 'VBAFacility' do
    let(:type) { VAFacility::BENEFITS }
    it 'should save and retrieve all attributes and they should match the original object' do
      VCR.use_cassette('facilities/va/ny_benefits') do
        va_facility.attributes.each_key do |attr|
          original = va_facility.send(attr)
          original.deep_stringify_keys! if original.is_a?(Hash)
          expect(vba_facility[attr]).to eq(original)
        end
      end
    end
  end

  describe 'NCAFacility' do
    let(:type) { VAFacility::CEMETERY }
    it 'should save and retrieve all attributes and they should match the original object' do
      VCR.use_cassette('facilities/va/ny_cemetery') do
        va_facility.attributes.each_key do |attr|
          original = va_facility.send(attr)
          original.deep_stringify_keys! if original.is_a?(Hash)
          expect(nca_facility[attr]).to eq(original)
        end
      end
    end
  end

  describe '#query' do
    it 'should find facility in the bbox' do
      create :vha_648A4
      bbox = ['-122.440689', '45.451913', '-122.786758', '45.64']
      expect(BaseFacility.query(bbox: bbox).data.first.id).to eq('648A4')
    end
  end

  describe '#find_facility_by_id' do
    before(:each) { create :vha_648A4 }
    it 'should find facility by id' do
      expect(BaseFacility.find_facility_by_id('vha_648A4').id).to eq('648A4')
    end
    it 'should have hours that are sorted by day' do
      expect(BaseFacility.find_facility_by_id('vha_648A4').hours.keys).to eq(DateTime::DAYNAMES.rotate)
    end
  end
end
