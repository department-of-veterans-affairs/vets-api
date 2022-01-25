# frozen_string_literal: true

require 'json_marshal/marshaller'

module CovidVaccine
  module V0
    class RegistrationSubmission < ApplicationRecord
      scope :for_user, ->(user) { where(account_id: user.account_uuid).order(created_at: :asc) }

      after_initialize do |reg|
        reg.form_data&.symbolize_keys!
      end

      serialize :form_data, JsonMarshal::Marshaller
      serialize :raw_form_data, JsonMarshal::Marshaller
      has_kms_key
      encrypts :form_data, :raw_form_data, key: :kms_key, **lockbox_options
    end
  end
end
