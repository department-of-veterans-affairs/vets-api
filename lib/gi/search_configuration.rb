# frozen_string_literal: true

module GI
  class SearchConfiguration < GI::Configuration
    self.read_timeout = Settings.gids.search&.read_timeout || 4
    self.open_timeout = Settings.gids.search&.open_timeout || 4

    # Mock response if querying for flight school programs
    # TO-DO: Remove after flight school program data becomes accessible
    def use_mocks?
      (@program_type_flight && Settings.gids.search.use_mocks) || false
    end
  end
end
