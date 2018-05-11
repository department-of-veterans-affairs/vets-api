# frozen_string_literal: true

require 'facilities/client'

class BaseFacility < ActiveRecord::Base
  include Facilities::FacilityMapping
  self.inheritance_column = 'facility_type'
  self.primary_key = 'unique_id'
  after_initialize :generate_fingerprint

  class << self
    include Facilities::FacilityMapping
    def find_sti_class(type_name)
      FACILITY_MAPPINGS[type_name].constantize || super
    end

    def sti_name
      FACILITY_MAPPINGS.invert[name]
    end

    def pull_source_data
      metadata = Facilities::MetadataClient.new.get_metadata(FACILITY_SORT_FIELDS[name].first)
      max_record_count = metadata['maxRecordCount']
      Facilities::Client.new.get_all_facilities(*FACILITY_SORT_FIELDS[name], max_record_count).map(&method(:new))
    end

    def find_facility_by_id(id)
      type, unique_id = id.split('_')
      return nil unless type && unique_id
      facility = "Facilities::#{type.upcase}Facility".constantize.find_by(unique_id: unique_id)
      facility&.hours = facility&.hours&.sort_by { |day, _hours| DAYS[day.capitalize] }.to_h
      facility
    end

    def query(params)
      return BaseFacility.none unless params[:bbox]
      bbox_num = params[:bbox].map { |x| Float(x) }
      build_result_set(bbox_num, params[:type], params[:services]).sort_by(&(dist_from_center bbox_num))
    end

    def build_result_set(bbox_num, type, services)
      lats = bbox_num.values_at(1, 3)
      longs = bbox_num.values_at(2, 0)
      conditions = { lat: (lats.min..lats.max), long: (longs.min..longs.max) }
      TYPES.map { |facility_type| get_facility_data(conditions, type, facility_type, services) }.flatten
    end

    def get_facility_data(conditions, type, facility_type, services)
      klass = TYPE_MAP[facility_type].constantize
      return klass.none unless type.blank? || type == facility_type
      facilities = klass.where(conditions)
      facilities = facilities.where("services->'benefits'->'standard' @> '#{services}'") if services&.any?
      facilities = facilities.where.not(facility_type: 'dod_health')
      facilities
    end

    # Naive distance calculation, but accurate enough for map display sorting.
    # If greater precision is ever needed, use Haversine formula.
    def dist_from_center(bbox)
      lambda do |facility|
        center_x = (bbox[0] + bbox[2]) / 2.0
        center_y = (bbox[1] + bbox[3]) / 2.0
        Math.sqrt((facility.long - center_x)**2 + (facility.lat - center_y)**2)
      end
    end

    def per_page
      20
    end

    def max_per_page
      100
    end

    def suggested(facility_types, name_part)
      BaseFacility.where(
        facility_type: facility_types.map { |t| TYPE_NAME_MAP[t] }
      ).where('name ILIKE ?', "%#{name_part}%")
    end
  end

  private

  def generate_fingerprint
    self.fingerprint = Digest::SHA2.hexdigest(attributes.to_s) if new_record?
  end
end
