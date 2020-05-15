# frozen_string_literal: true

module MDOT
  class FormAddressInformation
    include Virtus.model
    attribute :permanent_address, MDOT::Address
    attribute :temporary_address, MDOT::Address
  end

  class FormSupplyInformation
    include Virtus.model
    attribute :available, Array[MDOT::Supply]
    attribute :eligibility, MDOT::Eligibility
  end
end

class FormProfiles::MDOT < FormProfile
  attribute :mdot_contact_information, MDOT::FormAddressInformation
  attribute :mdot_supplies, MDOT::FormSupplyInformation

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end

  def prefill(user)
    @response = MDOT::Client.new(user).get_supplies
    @mdot_contact_information = initialize_mdot_contact_information(@response)
    @mdot_supplies = initialize_mdot_supplies(@response)
    super(user)
  end

  private

  def initialize_mdot_contact_information(response)
    MDOT::FormAddressInformation.new(
      permanent_address: response&.permanent_address,
      temporary_address: response&.temporary_address
    )
  end

  def initialize_mdot_supplies(response)
    MDOT::FormSupplyInformation.new(
      available: response&.supplies,
      eligibility: response&.eligibility
    )
  end
end
