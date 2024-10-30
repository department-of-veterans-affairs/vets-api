# frozen_string_literal: true

class ClaimVANotification < ApplicationRecord
  belongs_to :saved_claim

  validates :form_type, presence: true
  validates :email_template_id, presence: true
  validates :email_sent, inclusion: { in: [true, false] }
end
