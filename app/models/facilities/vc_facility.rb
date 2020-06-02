# frozen_string_literal: true

require 'facilities/metadata/client'

module Facilities
  class VCFacility < BaseFacility
    class << self
      def pull_source_data
        metadata = Facilities::Metadata::Client.new.get_metadata(arcgis_type)
        max_record_count = metadata['maxRecordCount']
        Facilities::Client.new.get_all_facilities(arcgis_type, sort_field, max_record_count).map(&method(:new))
      end

      def service_list
        []
      end

      def arcgis_type
        'VHA_VetCenters'
      end

      def sort_field
        'stationno'
      end

      def attribute_map
        {
          'unique_id' => 'stationno',
          'name' => 'stationname',
          'classification' => 'vet_center',
          'phone' => { 'main' => 'sta_phone' },
          'physical' => { 'address_1' => 'address2', 'address_2' => 'address3',
                          'address_3' => '', 'city' => 'city', 'state' => 'st',
                          'zip' => 'zip' },
          'hours' => BaseFacility::HOURS_STANDARD_MAP.each_with_object({}) { |(k, v), h| h[k.downcase] = v.downcase },
          'mapped_fields' => %w[stationno stationname lat lon address2 address3 city st zip sta_phone
                                monday tuesday wednesday thursday friday saturday sunday]
        }
      end
    end
  end
end
