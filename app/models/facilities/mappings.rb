# frozen_string_literal: true

module Facilities
  class Mappings
    CLASS_MAP = {
      'nca' => Facilities::NCAFacility,
      'vha' => Facilities::VHAFacility,
      'vba' => Facilities::VBAFacility,
      'vc' => Facilities::VCFacility
    }.freeze

    PATHMAP = { 'NCA_Facilities' => Facilities::NCAFacility,
                'VBA_Facilities' => Facilities::VBAFacility,
                'VHA_VetCenters' => Facilities::VCFacility,
                'FacilitySitePoint_VHA' => Facilities::VHAFacility }.freeze
  end
end
