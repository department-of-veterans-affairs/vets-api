# frozen_string_literal: true

require 'common/client/base'
require 'facilities/metadata/client'
require_relative 'metadata_configuration'

module Facilities
  module Gis
    class MetadataClient < Facilities::Metadata::Client
      configuration Facilities::Gis::MetadataConfiguration
    end
  end
end
