require 'common/models/base'

class PPMS::Service < Common::Base
  include ActiveModel::Serializers::JSON

  attribute :specialty_code, String
  attribute :grouping, String
  attribute :classification, String
  attribute :specialization, String
  attribute :specialty_description, String

end