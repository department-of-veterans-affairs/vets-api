# frozen_string_literal: true

module AccreditedRepresentativePortal
  class IcnTemporaryIdentifier < ApplicationRecord
    def self.lookup_icn(uuid)
      find(uuid).icn
    end

    def self.save_icn(icn)
      find_or_create_by(icn:)
    end
  end
end
