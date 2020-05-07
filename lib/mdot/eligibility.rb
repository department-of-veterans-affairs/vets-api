# frozen_string_literal: true

module MDOT
  class Eligibility
    include Virtus.model

    attribute :batteries, Boolean
    attribute :accessories, Boolean
  end
end
