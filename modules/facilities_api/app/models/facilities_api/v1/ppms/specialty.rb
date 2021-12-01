# frozen_string_literal: true

module FacilitiesApi
  class V1::PPMS::Specialty < Common::Base
    attribute :classification, String
    attribute :grouping, String
    attribute :name, String
    attribute :specialization, String
    attribute :specialty_code, String
    attribute :specialty_description, String

    def initialize(attr = {})
      super(attr)
      new_attr = attr.dup.transform_keys { |k| k.to_s.snakecase.to_sym }
      new_attr[:specialty_code] ||= new_attr.delete(:coded_specialty)

      self.attributes = new_attr
    end
  end
end
