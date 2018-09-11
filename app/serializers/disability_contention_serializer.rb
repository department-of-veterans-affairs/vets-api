# frozen_string_literal: true

class DisabilityContentionSerializer < ActiveModel::Serializer
  attribute :code
  attribute :medical_term
  attribute :lay_term
end
