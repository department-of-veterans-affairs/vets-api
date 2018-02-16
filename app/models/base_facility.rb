# frozen_string_literal: true

class BaseFacility < ActiveRecord::Base
  self.primary_key = 'unique_id'

  def self.generate_fingerprint(json_attributes)
    Digest::SHA2.hexdigest json_attributes
  end
end
