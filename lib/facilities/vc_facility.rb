# frozen_string_literal: true

module Facilities
  class VCFacility < BaseFacility

  	class << self
	    attr_writer :validate_on_load
	    
	    def pull_source_data
	      metadata = Facilities::MetadataClient.new.get_metadata(arcgis_type)
	      max_record_count = metadata['maxRecordCount']
	      Facilities::Client.new.get_all_facilities(arcgis_type, sort_field, max_record_count).map(&method(:new))
	    end

	    def arcgis_type
	    	'VHA_VetCenters'
	    end

	    def sort_field
	    	'stationno'
	    end
	  end
	end
end
