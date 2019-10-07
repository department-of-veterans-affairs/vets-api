# frozen_string_literal: true

require 'common/client/base'

module Facilities
  class DriveTimeBandMetadataClient < Common::Client::Base
    configuration Facilities::DriveTimeBandMetadataConfiguration

    def get_metadata
      resp = perform(:get, "/", f: 'json')
      JSON.parse resp.body
    end
  end
end
