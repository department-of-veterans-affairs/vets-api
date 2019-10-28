# frozen_string_literal: true

module VaForms
  class Form < ApplicationRecord
    has_paper_trail

    validates :title, presence: true
    validates :form_name, presence: true, uniqueness: true
    validates :url, presence: true
    validates :sha256, presence: true

    before_save :set_revision

    private

    def set_revision
      self.last_revision_on = first_issued_on if last_revision_on.blank?
    end
  end
end
