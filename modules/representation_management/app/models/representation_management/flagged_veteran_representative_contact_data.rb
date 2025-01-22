# frozen_string_literal: true

module RepresentationManagement
  class FlaggedVeteranRepresentativeContactData < ApplicationRecord
    self.table_name = 'flagged_veteran_representative_contact_data'

    enum :flag_type, { phone_number: 'phone_number', email: 'email', address: 'address', other: 'other' }, suffix: true
    validates :ip_address, :representative_id, :flag_type, :flagged_value, presence: true
    validates :ip_address,
              uniqueness: { scope: %i[representative_id flag_type flagged_value_updated_at], message: 'Combination of ip_address, representative_id, flag_type, and flagged_value_updated_at must be unique' } # rubocop:disable Rails/I18nLocaleTexts,Layout/LineLength
  end
end
