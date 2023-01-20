# frozen_string_literal: true

class UserAcceptableVerifiedCredential < ApplicationRecord
  belongs_to :user_account, dependent: nil, optional: false
end
