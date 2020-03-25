# frozen_string_literal: true

require 'common/client/base'

module Facilities
  module Gis
    # Core class responsible for api interface operations
    class Client < Facilities::Client
      configuration Facilities::Gis::Configuration

      def build_params(order_field, offset)
        { where: "s_abbr!='VTCR' AND s_abbr!='MVCTR'", inSR: 4326, outSR: 4326, returnGeometry: true,
          returnCountOnly: false, outFields: '*', returnDistinctValues: false,
          orderByFields: order_field, f: 'json', resultOffset: offset }
      end
    end
  end
end
