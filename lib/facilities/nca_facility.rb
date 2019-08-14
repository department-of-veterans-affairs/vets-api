# frozen_string_literal: true

module Facilities
  class NCAFacility < BaseFacility

	  class << self
		attr_writer :validate_on_load
	    
	    def pull_source_data
	      metadata = Facilities::MetadataClient.new.get_metadata(arcgis_type)
	      max_record_count = metadata['maxRecordCount']
	      Facilities::Client.new.get_all_facilities(arcgis_type, sort_field, max_record_count).map(&method(:new))
	    end

	    def arcgis_type
	    	'NCA_Facilities'
	    end

	    def sort_field
	    	'SITE_ID'
	    end
	  end
	end
end
