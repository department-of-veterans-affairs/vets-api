# frozen_string_literal: true

require 'vets/model'
require 'digest'

# facility extract statuses, part of PHR refresh.
class ExtractStatus
  include Vets::Model

  attribute :extract_type, String
  attribute :last_updated, Vets::Type::UTCTime
  attribute :status, String
  attribute :created_on, Vets::Type::UTCTime
  attribute :station_number, String

  def id
    Digest::SHA256.hexdigest(instance_variable_get(:@original_attributes).to_json)
  end
end
