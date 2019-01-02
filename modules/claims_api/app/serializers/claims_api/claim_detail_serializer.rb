# frozen_string_literal: true

module ClaimsApi
  class ClaimDetailSerializer < EVSSClaimDetailSerializer
    attribute :status

    def attributes(*args)
      hash = super
      hash.delete(:phase)
      hash
    end

    def status
      object.status_from_phase(phase)
    end
  end
end
