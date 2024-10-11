# frozen_string_literal: true

require 'backend_services'

# TO-DO: After transition of Post-911 GI Bill to 24/7 availability, confirm
# BackendStatus (singular) model and related logic can be removed
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

  def available?
    service_subject_to_downtime? ? BenefitsEducation::Service.within_scheduled_uptime? : true
  end

  def uptime_remaining
    service_subject_to_downtime? ? BenefitsEducation::Service.seconds_until_downtime.to_i : 0
  end

  private

  def service_subject_to_downtime?
    return false if Flipper.enabled?(:sob_updated_design)

    @name == BackendServices::GI_BILL_STATUS
  end
end
