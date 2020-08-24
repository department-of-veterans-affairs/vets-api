# frozen_string_literal: true

# This service manages the interactions between Ask and Dynamics 365.
module Ask
  class AskService

    def initialize(claim)
      @claim = claim
    end

    def post_to_xrm
      # get client url or define client url (something fake)
      # parse/translate claim
      # create to entity to add to data entry in Dynamics
      0
    end
  end
end