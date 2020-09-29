# frozen_string_literal: true

module Form1010cg
  # A Form1010CG::Submission is the submission of a CaregiversAssistanceClaim (form 10-10CG)
  # Used to store data of the relating record created in CARMA.
  #
  # More information about CARMA can be found in lib/carma/README.md
  #
  class Submission
    attr_accessor :carma_case_id, # The id of the Case returned by CARMA (from the submission response)
                  :submitted_at, # The timestamp of when this record was created by CARMA (from the submission response)
                  :attachments, # The raw response body (from the attachments upload request)
                  :metadata # The raw metadata send to CARMA (on the submission request)

    def initialize(args = {})
      @carma_case_id = args[:carma_case_id]
      @submitted_at = args[:submitted_at]
      @attachments = args[:attachments] || {}
      @metadata = args[:metadata]
    end
  end
end
