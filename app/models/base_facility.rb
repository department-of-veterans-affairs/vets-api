# frozen_string_literal: true

require 'facilities/shared_client'

class BaseFacility < ActiveRecord::Base
  self.inheritance_column = 'facility_type'
  self.primary_key = 'unique_id'
  after_initialize :generate_fingerprint

  FACILITY_MAPPINGS = {
    'va_cemetery' => 'Facilities::NCAFacility',
    'va_benefits_facility' => 'Facilities::VBAFacility',
    'vet_center' => 'Facilities::VCFacility',
    'va_health_facility' => 'Facilities::VHAFacility'
  }.freeze

  FACILITY_SORT_FIELDS = {
    'Facilities::NCAFacility' => %w[NCA_Facilities SITE_ID],
    'Facilities::VBAFacility' => %w[VBA_Facilities Facility_Number],
    'Facilities::VCFacility' => %w[VHA_VetCenters stationno],
    'Facilities::VHAFacility' => %w[VHA_Facilities StationNumber]
  }.freeze

  class << self
    def find_sti_class(type_name)
      FACILITY_MAPPINGS[type_name].constantize || super
    end

    def sti_name
      FACILITY_MAPPINGS.invert[name]
    end

    def pull_source_data
      metadata = Facilities::MetadataClient.new.get_metadata(FACILITY_SORT_FIELDS[name].first)
      max_record_count = metadata['maxRecordCount']
      Facilities::SharedClient.new.get_all_facilities(*FACILITY_SORT_FIELDS[name], max_record_count).map(&method(:new))
    end
  end

  private

  def generate_fingerprint
    self.fingerprint = Digest::SHA2.hexdigest(attributes.to_s) if new_record?
  end
end
