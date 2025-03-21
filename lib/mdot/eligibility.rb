# frozen_string_literal: true

module MDOT
  class Eligibility
    include Virtus.model

    attribute :batteries, Boolean, default: false
    attribute :accessories, Boolean, default: false
    attribute :apneas, Boolean, default: false
    attribute :assistive_devices, Boolean, default: false
  end
end
