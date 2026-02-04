# app/models/veteran/service/organization_representative.rb
module Veteran
  module Service
    class OrganizationRepresentative < ApplicationRecord
      self.table_name = 'organization_representatives'

      belongs_to :representative,
                 class_name: 'Veteran::Service::Representative',
                 foreign_key: :representative_id,
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
        disabled: 'disabled'
      }, default: 'disabled'

      validates :representative_id, presence: true
      validates :organization_poa, presence: true
      validates :representative_id, uniqueness: { scope: :organization_poa }
    end
  end
end
