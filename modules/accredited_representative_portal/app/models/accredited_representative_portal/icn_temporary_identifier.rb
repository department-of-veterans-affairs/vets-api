# frozen_string_literal: true

module AccreditedRepresentativePortal
  class IcnTemporaryIdentifier < ApplicationRecord
    EXPIRATION_PERIOD = 60.days.freeze

    has_kms_key
    has_encrypted(:icn, key: :kms_key, **lockbox_options)

    scope :not_expired, -> { where('created_at >= ?', EXPIRATION_PERIOD.ago) }
    scope :expired, -> { where('created_at < ?', EXPIRATION_PERIOD.ago) }

    def self.lookup_uuid(uuid)
      not_expired.find(uuid).icn
    end

    def self.cleanup_expired!
      expired.delete_all
    end
  end
end
