# frozen_string_literal: true

module FacilitiesQuery
  class BoundingBoxQuery < Base
    def run
      bbox_num = @params[:bbox].map { |x| Float(x) }
      build_result_set(bbox_num, @params[:type], @params[:services]).sort_by(&(dist_from_center bbox_num))
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

    def build_result_set(bbox_num, type, services)
      lats = bbox_num.values_at(1, 3)
      longs = bbox_num.values_at(2, 0)
      conditions = { lat: (lats.min..lats.max), long: (longs.min..longs.max) }
      BaseFacility::TYPES.flat_map { |facility_type| get_facility_data(conditions, type, facility_type, services) }
    end
  end
end
