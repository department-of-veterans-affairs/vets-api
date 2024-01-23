# frozen_string_literal: true

module Veteran
  class FlaggedVeteranRepresentativeContactData < ApplicationRecord
    self.table_name = 'flagged_veteran_representative_contact_data'

    attribute :flag_type, :flag_type
    validates :ip_address, :representative_id, :flag_type, presence: true
    validates :flag_type, inclusion: { in: ActiveRecord::Type.lookup(:flag_type).valid_types }
    validates :ip_address, uniqueness: { scope: %i[representative_id flag_type],
                                         message: 'Combination of representative_id, flag_type, and flagged_value must be unique' } # rubocop:disable Layout/LineLength,Rails/I18nLocaleTexts
  end
end
