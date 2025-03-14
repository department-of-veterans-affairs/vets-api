# frozen_string_literal: true

module AccreditedRepresentativePortal
  class IcnTemporaryIdentifier < ApplicationRecord
    EXPIRATION_PERIOD = 60.days.freeze

    scope :not_expired, -> { where('created_at >= ?', EXPIRATION_PERIOD.ago) }
    scope :expired, -> { where('created_at < ?', EXPIRATION_PERIOD.ago) }

    def self.lookup_icn(uuid)
      not_expired.find(uuid).icn
    end

    def self.save_icn(icn)
      not_expired.find_or_create_by(icn:)
    end

    def self.cleanup_expired!
      expired.delete_all
    end
  end
end
