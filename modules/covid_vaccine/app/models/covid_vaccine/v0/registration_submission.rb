# frozen_string_literal: true

require 'json_marshal/marshaller'

module CovidVaccine
  module V0
    class RegistrationSubmission < ApplicationRecord
      scope :for_user, ->(user) { where(account_id: user.account_uuid).order(created_at: :asc) }

      serialize :form_data, coder: JsonMarshal::Marshaller
      serialize :raw_form_data, coder: JsonMarshal::Marshaller
      has_kms_key
      has_encrypted :form_data, :raw_form_data, key: :kms_key, **lockbox_options
    end
  end
end
