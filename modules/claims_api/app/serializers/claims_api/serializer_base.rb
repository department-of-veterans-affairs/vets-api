# frozen_string_literal: true

module ClaimsApi
  module SerializerBase
    REMOVE_ATTRIBUTES = %i[
      phase
      phase_change_date
      ever_phase_back
      current_phase_back
    ].freeze

    def attributes(*args)
      hash = super
      REMOVE_ATTRIBUTES.each { |attr| hash.delete(attr) }
      hash
    end

    def status
      object.status_from_phase(phase)
    end
  end
end
