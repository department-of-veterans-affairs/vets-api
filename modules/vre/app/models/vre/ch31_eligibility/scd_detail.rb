# frozen_string_literal: true

module VRE
  module Ch31Eligibility
    class ScdDetail
      include Vets::Model

      attribute :code, String
      attribute :name, String
      attribute :percentage, String
    end
  end
end
