# frozen_string_literal: true

module VRE
  module Ch31CaseDetails
    class State
      include Vets::Model

      attribute :step_code, String
      attribute :status, String
    end
  end
end
