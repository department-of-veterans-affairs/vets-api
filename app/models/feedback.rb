# frozen_string_literal: true
class Feedback
  include ActiveModel::Validations
  include Virtus.model(nullify_blank: true)

  attribute :target_page, String
  attribute :description, String
  attribute :owner_email, String

  validates :target_page, presence: true
  validates :description, presence: true
end