# frozen_string_literal: true

module Veteran
  class FlaggedVeteranRepresentativeContactData < ApplicationRecord
    self.table_name = 'flagged_veteran_representative_contact_data'

    enum flag_type: { phone: 'phone', email: 'email', address: 'address', other: 'other' }, _suffix: true
    validates :ip_address, :representative_id, :flag_type, :flagged_value, presence: true
    validates :ip_address, uniqueness: { scope: %i[representative_id flag_type],
                                         message: 'Combination of ip_address, representative_id, and flag_type must be unique' } # rubocop:disable Layout/LineLength,Rails/I18nLocaleTexts
  end
end
