# frozen_string_literal: true

require 'mdot/address'
require 'mdot/client'
require 'mdot/eligibility'
require 'mdot/supply'

module MDOT
  class FormContactInformation
    include Virtus.model
    attribute :permanent_address, MDOT::Address
    attribute :temporary_address, MDOT::Address
    attribute :vet_email, String
  end

  class FormSupplyInformation
    include Virtus.model
    attribute :available, Array[MDOT::Supply]
    attribute :eligibility, MDOT::Eligibility
  end
end

class FormProfiles::MDOT < FormProfile
  attribute :mdot_contact_information, MDOT::FormContactInformation
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
    MDOT::FormContactInformation.new(
      permanent_address: response&.permanent_address,
      temporary_address: response&.temporary_address,
      vet_email: response&.vet_email
    )
  end

  def initialize_mdot_supplies(response)
    MDOT::FormSupplyInformation.new(
      available: response&.supplies,
      eligibility: response&.eligibility
    )
  end
end
