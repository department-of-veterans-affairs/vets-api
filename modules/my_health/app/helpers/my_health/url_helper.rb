# frozen_string_literal: true

module MyHealth
  class UrlHelper
    # TODO: Should we do memoization to avoid creating a new instance of the engine's url_helpers?
    include MyHealth::Routing
  end
end
