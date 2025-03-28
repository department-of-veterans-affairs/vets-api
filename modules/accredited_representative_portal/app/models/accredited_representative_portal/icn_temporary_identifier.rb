# frozen_string_literal: true

module AccreditedRepresentativePortal
  class IcnTemporaryIdentifier < ApplicationRecord
    EXPIRATION_PERIOD = 60.days.freeze

    def self.lookup_icn(uuid)
      find(uuid).icn
    end

    def self.save_icn(icn)
      find_or_create_by(icn:)
    end
  end
end
