# frozen_string_literal: true

module DebtsApi
  class V0::DigitalDispute
    # Currently just provides the stats key constant used by the controller
    # In the future will handle forwarding to DMC / storage

    STATS_KEY = 'api.digital_dispute_submission'
  end
end
