# frozen_string_literal: true

require 'rails_helper'
require 'va_facilities/geo_serializer'

RSpec.describe VaFacilities::GeoSerializer do
	let(:vha_facility) { build :vha_648A4 }

	context '::geometry' do
		it 'makes a geometry object' do
			geo_object = VaFacilities::GeoSerializer.geometry(vha_facility)

			expect(geo_object.keys).to eq(['type', 'coordinates'])
			expect(geo_object.values).to eq(["Point", [vha_facility.long, vha_facility.lat]])
		end
	end

	context '::properties' do
		it 'collects basic facility attributes' do
			property_object = VaFacilities::GeoSerializer.properties(vha_facility)

			expected_property_keys = [
				'id', 
				'name', 
				'facility_type', 
				'classification',
				'website',
				'address',
				'phone',
				'hours',
				'services',
				'satisfaction',
				'wait_times',
				'mobile',
				'active_status'
			]
			simple_keys = expected_property_keys - ['id', 'services', 'satisfaction', 'wait_times']

			simple_keys.each do |key|
				expect(property_object[key]).to eq(vha_facility.send(key.to_sym))
			end
			expect(property_object.keys).to eq(expected_property_keys)
		end
	end
	
	context '::to_feature_collection' do
		let(:vha_facility2) { build :vha_402QA }
		it 'convert collection to geojson format' do 
			geojson = VaFacilities::GeoSerializer.to_feature_collection([vha_facility, vha_facility2])

			expect(geojson.keys).to eq(['type', 'features'])
			expect(geojson['type']).to eq('FeatureCollection')
			expect(geojson['features'].size).to eq(2)
			expect(geojson['features'].first.keys).to eq(['type', 'geometry', 'properties'])
			expect(geojson['features'].first['type']).to eq('Feature')
		end
	end

end