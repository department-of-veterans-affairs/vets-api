# frozen_string_literal: true

module Vye
  class Vye::PendingDocument < ApplicationRecord
    self.ignored_columns += %i[claim_no_ciphertext encrypted_kms_key ssn_ciphertext ssn_digest]

    belongs_to :user_profile

    validates :doc_type, :queue_date, :rpo, presence: true
  end
end
