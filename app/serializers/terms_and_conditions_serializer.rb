# frozen_string_literal: true
class TermsAndConditionsSerializer < ActiveModel::Serializer
  attribute :id
  attribute :name
  attribute :title
  attribute :text
  attribute :version
  attribute :created_at
  attribute :updated_at
end
