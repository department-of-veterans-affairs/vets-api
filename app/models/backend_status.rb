# frozen_string_literal: true

require 'backend_services'

class BackendStatus
  include ActiveModel::Serialization
  include ActiveModel::Validations
  include Virtus.model(nullify_blank: true)

  attribute :name, String
  attribute :service_id, String
  attribute :is_available, Boolean
  attribute :uptime_remaining, Integer

  validates :name, presence: true
  validates :is_available, presence: true
  validates :uptime_remaining, presence: true
end
