# frozen_string_literal: true

require 'vets/model'

module MDOT
  class Eligibility
    include Vets::Model

    attribute :batteries, Bool, default: false
    attribute :accessories, Bool, default: false
    attribute :apneas, Bool, default: false
    attribute :assistive_devices, Bool, default: false
  end
end
