# frozen_string_literal: true

module ClaimsApi
  module SerializerBase
    def status
      object.status_from_phase(phase)
    end
  end
end
