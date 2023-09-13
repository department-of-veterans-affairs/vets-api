# frozen_string_literal: true

module VBADocuments
  class MonthlyStat < ApplicationRecord
    validates :month, inclusion: { in: (1..12).to_a }, presence: true, uniqueness: { scope: :year }
    validates :year, format: { with: /\A2\d{3}\z/ }, presence: true
  end
end
