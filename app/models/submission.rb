# frozen_string_literal: true

class Submission < ApplicationRecord
  self.abstract_class = true

  validates :form_id, presence: true
end
