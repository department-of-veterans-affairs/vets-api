# frozen_string_literal: true
class IdCardAnnouncementSubscription < ActiveRecord::Base
  validates :email,
            uniqueness: true,
            length: { maximum: 255 },
            format: { with: /\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/ } # Devise::email_regexp

  scope :va, -> { where("split_part(email, '@', 2) = 'va.gov'") }
  scope :non_va, -> { where("split_part(email, '@', 2) <> 'va.gov'") }
end
