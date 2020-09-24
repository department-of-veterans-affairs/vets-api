# frozen_string_literal: true

require 'common/models/base'
require 'digest'

# facility extract statuses, part of PHR refresh.
class ExtractStatus < Common::Base
  attribute :extract_type, String
  attribute :last_updated, Common::UTCTime
  attribute :status, String
  attribute :created_on, Common::UTCTime
  attribute :station_number, String

  def id
    Digest::SHA256.hexdigest(instance_variable_get(:@original_attributes).to_json)
  end
end
