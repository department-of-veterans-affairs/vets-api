# frozen_string_literal: true

module SignIn
  class WebauthnCredential < ApplicationRecord
    self.table_name = 'sign_in_webauthn_credentials'

    has_one :user_verification, dependent: :destroy

    validates :credential_id, presence: true, uniqueness: true
    validates :public_key, :sign_count, :transports, presence: true
    validates :backup_eligible, :backed_up, inclusion: { in: [true, false] }
  end
end
