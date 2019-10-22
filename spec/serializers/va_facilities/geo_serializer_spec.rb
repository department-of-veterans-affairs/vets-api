# frozen_string_literal: true

require 'rails_helper'
require 'va_facilities/geo_serializer'

RSpec.describe VaFacilities::GeoSerializer do
  let(:vha_facility) { build :vha_648A4 }

  context '::geometry' do
    it 'makes a geometry object' do
      geo_object = VaFacilities::GeoSerializer.geometry(vha_facility)

      expect(geo_object.keys).to eq(%w[type coordinates])
      expect(geo_object.values).to eq(['Point', [vha_facility.long, vha_facility.lat]])
    end
  end

  context '::properties' do
    it 'collects basic facility attributes' do
      property_object = VaFacilities::GeoSerializer.properties(vha_facility)

      expected_property_keys = %w[
        id
        name
        facility_type
        classification
        website
        address
        phone
        hours
        services
        satisfaction
        wait_times
        mobile
        active_status
      ]
      simple_keys = expected_property_keys - %w[id services satisfaction wait_times]

      simple_keys.each do |key|
        expect(property_object[key]).to eq(vha_facility.send(key.to_sym))
      end
      expect(property_object.keys).to eq(expected_property_keys)
    end

    it 'includes id' do
      property_object = VaFacilities::GeoSerializer.properties(vha_facility)

      expect(property_object['id']).to eq('vha_648A4')
    end

    it 'includes satisfaction' do
      property_object = VaFacilities::GeoSerializer.properties(vha_facility)

      expected_satisfaction = {
        'health' => {
          'primary_care_urgent' => 0.8,
          'primary_care_routine' => 0.84
        },
        'effective_date' => '2017-08-15'
      }
      expect(property_object['satisfaction']).to eq(expected_satisfaction)
    end

    it 'includes wait times' do
      property_object = VaFacilities::GeoSerializer.properties(vha_facility)

      expected_wait_times = {
        'health' => [
          { 'service' => 'Audiology', 'new' => 35.0, 'established' => 18.0 },
          { 'service' => 'Optometry', 'new' => 38.0, 'established' => 22.0 },
          { 'service' => 'Dermatology', 'new' => 4.0, 'established' => nil },
          { 'service' => 'Ophthalmology', 'new' => 1.0, 'established' => 4.0 },
          { 'service' => 'PrimaryCare', 'new' => 34.0, 'established' => 5.0 },
          { 'service' => 'MentalHealth', 'new' => 12.0, 'established' => 3.0 }
        ],
        'effective_date' => '2018-02-26'
      }

      expect(property_object['wait_times']).to eq(expected_wait_times)
    end

    it 'includes services' do
      property_object = VaFacilities::GeoSerializer.properties(vha_facility)

      expected_services = {
        'health' => %w[DentalServices MentalHealthCare PrimaryCare],
        'last_updated' => '2018-03-15'
      }
      expect(property_object['services']).to eq(expected_services)
    end
  end

  context '::to_feature_collection' do
    let(:vha_facility2) { build :vha_402QA }

    it 'convert collection to geojson format' do
      geojson = VaFacilities::GeoSerializer.to_feature_collection([vha_facility, vha_facility2])

      expect(geojson.keys).to eq(%w[type features])
      expect(geojson['type']).to eq('FeatureCollection')
      expect(geojson['features'].size).to eq(2)
      expect(geojson['features'].first.keys).to eq(%w[type geometry properties])
      expect(geojson['features'].first['type']).to eq('Feature')
    end
  end
end
