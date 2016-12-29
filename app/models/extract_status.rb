# frozen_string_literal: true
require 'common/models/base'

# Folder model
class ExtractStatus < Common::Base
  attribute :extract_type, String
  attribute :last_updated, Common::UTCTime
  attribute :status, String
  attribute :created_on, Common::UTCTime
  attribute :station_number, String

  def <=>(other)
    extract_type <=> other.extract_type
  end
end
