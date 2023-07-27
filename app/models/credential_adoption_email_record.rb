# frozen_string_literal: true

class CredentialAdoptionEmailRecord < ApplicationRecord
  validates :icn, presence: true
  validates :email_address, presence: true
  validates :email_template_id, presence: true
end
