# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyForm < ApplicationRecord
    belongs_to :power_of_attorney_request,
               class_name: 'AccreditedRepresentativePortal::PowerOfAttorneyRequest',
               inverse_of: :power_of_attorney_form

    has_kms_key

    has_encrypted :data, key: :kms_key, **lockbox_options

    blind_index :city
    blind_index :state
    blind_index :zipcode

    # Validations
    validates :data_ciphertext, presence: true
  end
end
