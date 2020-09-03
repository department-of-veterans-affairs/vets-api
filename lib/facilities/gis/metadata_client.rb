# frozen_string_literal: true

require 'common/client/base'

module Facilities
  module Gis
    class MetadataClient < Facilities::Metadata::Client
      configuration Facilities::Gis::MetadataConfiguration
    end
  end
end
