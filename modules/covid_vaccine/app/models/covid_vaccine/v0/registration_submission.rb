# frozen_string_literal: true

module CovidVaccine
  module V0
    class RegistrationSubmission < ApplicationRecord
      scope :for_user, ->(user) { where(account_id: user.account_uuid).order(created_at: :asc) }

      attr_encrypted :form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller
    end
  end
end
