class PegaTable < ApplicationRecord
    # Validate presence of essential fields
    validates :uuid, presence: true
    validates :veteranfirstname, presence: true
    validates :veteranlastname, presence: true
    validates :response, presence: true
  
    validate :validate_response_format
  
    private
  


    def date_completed_after_date_created
        puts "DEBUG: date_completed: #{date_completed.inspect}, date_created: #{date_created.inspect}"
        return if date_completed.blank? || date_created.blank?
      
        if date_completed < date_created
          errors.add(:date_completed, "must be after the date created")
        end
      end
      
  
    def validate_response_format
      return unless response.present?
  
      response_hash = JSON.parse(response)
  
      # Check if 'status' key exists and its value is one of the HTTP status codes
      unless response_hash['status'].present? && [200, 403, 500].include?(response_hash['status'].to_i)
        errors.add(:response, "must contain a valid HTTP status code (200, 403, 500)")
      end
    rescue JSON::ParserError => e
      errors.add(:response, "must be a valid JSON format")
    end
  end
  