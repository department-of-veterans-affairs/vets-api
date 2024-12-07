# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyForm < ApplicationRecord
    belongs_to :power_of_attorney_request,
               class_name: 'AccreditedRepresentativePortal::PowerOfAttorneyRequest',
               foreign_key: :ar_power_of_attorney_request_id, # explicit foreign key
               inverse_of: :form

    has_kms_key
    has_encrypted :data_ciphertext, key: :kms_key, **lockbox_options

    blind_index :city
    blind_index :state
    blind_index :zipcode
  end
end
