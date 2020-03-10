# frozen_string_literal: true

module MDOT
  class FormSupply
    include Virtus.model
  end

  class FormPermanentAddress
    include Virtus.model
  end

  class FormTemporaryAddress
    include Virtus.model
  end
end

class FormProfiles::MDOT < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end

  def prefill(user)
    return {} unless user.authorize? :mdot, :access?
  end

  private

  def prefill_supplies(raw_supplies)
  end

  def prefill_permanent_address(raw_permanent_address)
  end

  def prefill_temporary_address(raw_temporary_address)
  end

  def initialize_supplies(user)
    client = MDOT::Client.new(user)
    supplies = client.get_supplies


  end
end
