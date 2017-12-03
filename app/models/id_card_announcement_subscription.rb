# frozen_string_literal: true
class IdCardAnnouncementSubscription < ActiveRecord::Base
  validates :email,
            uniqueness: true,
            format: { with: /\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/ } # Devise::email_regexp
end
