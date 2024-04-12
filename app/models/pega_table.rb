# frozen_string_literal: true

class PegaTable < ApplicationRecord
  # Validate presence of essential fields
  validates :uuid, presence: true
  validates :veteranfirstname, presence: true
  validates :veteranlastname, presence: true
  validates :response, presence: true

  validate :validate_response_format

  private

  def validate_response_format
    return if response.blank?

    response_hash = JSON.parse(response)
    unless response_hash['status'].present? && [200, 403, 500].include?(response_hash['status'].to_i)
      errors.add(:response, 'must contain a valid HTTP status code (200, 403, 500)')
    end
  rescue JSON::ParserError
    errors.add(:response, 'must be a valid JSON format')
  end
end
