# frozen_string_literal: true

module AppealsApi
  class EvidenceSubmission < ApplicationRecord
    belongs_to :supportable, polymorphic: true
  end
end
