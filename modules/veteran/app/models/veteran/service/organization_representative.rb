# frozen_string_literal: true

module Veteran
  module Service
    class OrganizationRepresentative < ApplicationRecord
      self.table_name = 'organization_representatives'

      belongs_to :representative,
                 class_name: 'Veteran::Service::Representative',
                 primary_key: :representative_id,
                 inverse_of: :organization_representatives

      belongs_to :organization,
                 class_name: 'Veteran::Service::Organization',
                 foreign_key: :organization_poa,
                 primary_key: :poa,
                 inverse_of: :organization_representatives

      enum :acceptance_mode, {
        any_request: 'any_request',
        self_only: 'self_only',
        no_acceptance: 'no_acceptance'
      }, default: 'no_acceptance', validate: true

      validates :organization_poa, presence: true
      validates :representative_id, uniqueness: { scope: :organization_poa }

      scope :active, -> { where(deactivated_at: nil) }
      scope :deactivated, -> { where.not(deactivated_at: nil) }

      def activate!
        return true if deactivated_at.nil?

        update!(deactivated_at: nil)
      end

      def deactivate!
        update!(deactivated_at: Time.current)
      end

      def self.deactivate!(ids)
        ids = Array(ids).compact
        return 0 if ids.empty?

        now = Time.current
        count = 0

        where(id: ids).find_each do |record|
          record.update!(deactivated_at: now)
          count += 1
        end

        count
      end
    end
  end
end
