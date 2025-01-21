# frozen_string_literal: true

class MHVOptInFlag < ApplicationRecord
  belongs_to :user_account, dependent: nil

  FEATURES = %w[secure_messaging].freeze

  attribute :user_account_id
  attribute :feature

  validates :feature, presence: true
  validates :feature, inclusion: { in: FEATURES }
end
