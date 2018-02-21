# frozen_string_literal: true

require 'shrine/plugins/storage_from_config'
require 'shrine/plugins/validate_virus_free'
class VetsShrine < Shrine
  plugin :validation_helpers
  plugin :metadata_attributes
  plugin :rack_file
  plugin :validate_virus_free
end
