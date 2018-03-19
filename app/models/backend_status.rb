# frozen_string_literal: true

require 'backend_services'


class BackendStatus
  include ActiveModel::Serialization
  include ActiveModel::Validations
  include Virtus.model(nullify_blank: true)

  attribute :name, String
  attribute :is_available, Boolean

  validates :name, presence: true
  validates :is_available, presence: true

end
