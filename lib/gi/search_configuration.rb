# frozen_string_literal: true

module GI
  class SearchConfiguration < GI::Configuration
    self.read_timeout = Settings.gids.search&.read_timeout || 4
    self.open_timeout = Settings.gids.search&.open_timeout || 4
  end
end
