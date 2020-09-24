# frozen_string_literal: true

class TermsAndConditionsSerializer < ActiveModel::Serializer
  attribute :id
  attribute :name
  attribute :title
  attribute :terms_content
  attribute :header_content
  attribute :yes_content
  attribute :no_content
  attribute :footer_content
  attribute :version
  attribute :created_at
  attribute :updated_at
end
