# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BaseFacility, type: :model do
  let(:bbox) { [-73.401, 40.685, -77.36, 43.03] }
  let(:services) { nil }
  let(:type) { VAFacility::VET_CENTER }
  let(:va_facilities) { VAFacility.query(bbox: bbox, type: type, services: services) }
  let(:va_facility) { va_facilities.first }
  let(:base_facility) { BaseFacility.create(va_facility.attributes) }
  it 'should save an item from a VAFacility object' do
    VCR.use_cassette('facilities/va/ny_vetcenter') do
      expect(base_facility.new_record?).to be false
      expect(BaseFacility.count).to eq(1)
    end
  end

  describe 'type: vet_center' do
    it 'should save and retrieve all attributes and they should match the original object' do
      VCR.use_cassette('facilities/va/ny_vetcenter') do
        va_facility.attributes.each_key do |attr|
          original = va_facility.send(attr)
          original.deep_stringify_keys! if original.is_a?(Hash)
          expect(base_facility[attr]).to eq(original)
        end
      end
    end
  end

  describe 'type: health' do
    let(:type) { VAFacility::HEALTH }
    it 'should save and retrieve all attributes and they should match the original object' do
      VCR.use_cassette('facilities/va/ny_health') do
        va_facility.attributes.each_key do |attr|
          original = va_facility.send(attr)
          original.deep_stringify_keys! if original.is_a?(Hash)
          expect(base_facility[attr]).to eq(original)
        end
      end
    end
  end

  describe 'type: benefits' do
    let(:type) { VAFacility::BENEFITS }
    it 'should save and retrieve all attributes and they should match the original object' do
      VCR.use_cassette('facilities/va/ny_benefits') do
        va_facility.attributes.each_key do |attr|
          original = va_facility.send(attr)
          original.deep_stringify_keys! if original.is_a?(Hash)
          expect(base_facility[attr]).to eq(original)
        end
      end
    end
  end

  describe 'type: cemetery' do
    let(:type) { VAFacility::CEMETERY }
    it 'should save and retrieve all attributes and they should match the original object' do
      VCR.use_cassette('facilities/va/ny_cemetery') do
        va_facility.attributes.each_key do |attr|
          original = va_facility.send(attr)
          original.deep_stringify_keys! if original.is_a?(Hash)
          expect(base_facility[attr]).to eq(original)
        end
      end
    end
  end
end
