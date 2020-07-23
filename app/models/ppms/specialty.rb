# frozen_string_literal: true

require 'common/models/base'

class PPMS::Specialty < Common::Base
  include ActiveModel::Serializers::JSON

  attribute :specialty_code, String
  attribute :grouping, String
  attribute :classification, String
  attribute :specialization, String
  attribute :specialty_description, String

  def initialize(attr)
    super(attr)
    new_attr = attr.dup
    new_attr[:specialty_code] ||= new_attr.delete(:coded_specialty)

    self.attributes = new_attr
  end
end
