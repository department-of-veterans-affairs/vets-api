# frozen_string_literal: true

module AppealsApi
  module V1
    class EvidenceSubmissionSerializer
      include FastJsonapi::ObjectSerializer

      set_key_transform :camel_lower
      attributes :status
      set_type :evidenceSubmission
    end
  end
end
