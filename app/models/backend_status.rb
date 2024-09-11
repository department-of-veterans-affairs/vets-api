# frozen_string_literal: true

require 'backend_services'

class BackendStatus
  include ActiveModel::Serialization
  include ActiveModel::Validations

  attr_reader :name, :service_id

  validates :name, presence: true
  validates :is_available, presence: true
  validates :uptime_remaining, presence: true

  def initialize(name:, service_id: nil)
    @name = name
    @service_id = service_id
  end

  def is_available
    gibs_service? ? BenefitsEducation::Service.within_scheduled_uptime? : true
  end

  def uptime_remaining
    gibs_service? ? BenefitsEducation::Service.seconds_until_downtime.to_i : 0
  end

  private

  def gibs_service?
    @name == BackendServices::GI_BILL_STATUS
  end
end
