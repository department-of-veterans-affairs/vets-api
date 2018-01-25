# frozen_string_literal: true

class TermsAndConditionsMiniSerializer < ActiveModel::Serializer
  attribute :id
  attribute :name
  attribute :version
  attribute :created_at
  attribute :updated_at
end
