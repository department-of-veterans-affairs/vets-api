# frozen_string_literal: true

require 'common/models/base'
require 'digest'

# BlueButton EligibleDataClasses
class EligibleDataClasses < Common::Base
  attribute :data_classes, Array[String]

  # checksum of the original attributes returned for uniqueness
  def id
    Digest::SHA256.hexdigest(instance_variable_get(:@original_attributes).to_json)
  end
end
