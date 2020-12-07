# frozen_string_literal: true

module CovidVaccine
  class RegistrationSubmission < ApplicationRecord
    scope :for_user, ->(user) { where(account_id: user.account_uuid).order(created_at: :asc) }
  end
end
