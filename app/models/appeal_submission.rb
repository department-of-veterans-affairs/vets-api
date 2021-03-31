# frozen_string_literal: true

class AppealSubmission < ApplicationRecord
  APPEAL_TYPES = %w[HLR NOD].freeze
  validates :user_uuid, :submitted_appeal_uuid, presence: true
  validates :type_of_appeal, inclusion: APPEAL_TYPES
end
