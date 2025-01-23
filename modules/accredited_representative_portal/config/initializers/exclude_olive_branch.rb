# frozen_string_literal: true

module AccreditedRepresentativePortal
  ##
  # This excludes ARP's API endpoints from `OliveBranch`'s redundant processing.
  # Redundant because we will have our serialization layer set our desired key
  # casing while constructing the response payload. `OliveBranch`, on the other
  # hand, deserializes JSON, transforms it, and serializes it again, which is
  # inefficient and redundant.
  #
  module ExcludeOliveBranch
    ARP_PATH_REGEX = %r{^/accredited_representative_portal/}

    private

    def exclude?(env, ...)
      env['REQUEST_PATH'] =~ ARP_PATH_REGEX || super
    end
  end
end

module OliveBranch
  class Middleware
    prepend AccreditedRepresentativePortal::ExcludeOliveBranch
  end
end
