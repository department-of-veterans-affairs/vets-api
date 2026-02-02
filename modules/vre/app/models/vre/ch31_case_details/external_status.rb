# frozen_string_literal: true

module VRE
  module Ch31CaseDetails
    class ExternalStatus
      include Vets::Model

      attribute :is_discontinued, Bool
      attribute :discontinued_reason, String
      attribute :is_interrupted, Bool, default: false
      attribute :interrupted_reason, String
      attribute :state_list, State, array: true
    end
  end
end
