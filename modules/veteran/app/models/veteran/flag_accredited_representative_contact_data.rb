# frozen_string_literal: true

module Veteran
  class FlaggedVeteranRepresentativeContactData < ApplicationRecord
    validates :ip_address, :representative_id, :flag_type, presence: true

    enum flag_type: { email: 'email', phone: 'phone', address: 'address', other: 'other' }
    validates :flag_type, inclusion: { in: flag_types.keys }

    validates :representative_id, uniqueness: { scope: %i[flag_type flagged_value],
                                                message: 'Combination of representative_id, flag_type, and flagged_value must be unique' } # rubocop:disable Layout/LineLength,Rails/I18nLocaleTexts
  end
end
