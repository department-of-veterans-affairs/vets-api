# frozen_string_literal: true

require 'fast_jsonapi'

module AppealsApi
  class EvidenceSubmissionSerializer
    include FastJsonapi::ObjectSerializer

    set_key_transform :camel_lower
    attributes :status
    set_type :evidenceSubmission
  end
end
