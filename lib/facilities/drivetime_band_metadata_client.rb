# frozen_string_literal: true

require 'common/client/base'

module Facilities
  class DrivetimeBandMetadataClient < Common::Client::Base
    configuration Facilities::DrivetimeBandMetadataConfiguration

    def get_metadata
      resp = perform(:get, "/arcgis2/rest/services/Portal/MonthlyVAST_TTB/FeatureServer/0?", f: 'json')
      JSON.parse resp.body
    end
  end
end
