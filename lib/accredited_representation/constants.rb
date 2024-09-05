# frozen_string_literal: true

module AccreditedRepresentation
  module Constants
    METERS_PER_MILE = 1609.344
    DEFAULT_MAX_MILES = 50
    DEFAULT_MAX_DISTANCE = DEFAULT_MAX_MILES * METERS_PER_MILE

    FUZZY_SEARCH_THRESHOLD = 0.5 # pg_search's default is 0.3

    MAX_PER_PAGE = 100
  end
end
