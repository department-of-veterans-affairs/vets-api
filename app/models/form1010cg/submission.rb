# frozen_string_literal: true

module Form1010cg
  class Submission
    ##
    # A Form1010CG::Submission is the submission of a CaregiversAssistanceClaim (form 10-10CG)
    # Used to store data of the relating record created in the form's ultimate destination (CARMA).
    #
    # More information about CARMA can be found in lib/carma/README.md

    attr_accessor :carma_case_id # The id of the CARMA Case created from this form submission
    attr_accessor :submitted_at # The timestamp of when the submission was accepted in CARMA

    def initialize(args = {})
      args.each { |key, value| send("#{key}=", value) }
    end
  end
end
