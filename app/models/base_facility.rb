# frozen_string_literal: true

class BaseFacility < ActiveRecord::Base
  self.primary_key = 'unique_id'
  after_initialize :generate_fingerprint

  private

  def generate_fingerprint
    self.fingerprint = Digest::SHA2.hexdigest(attributes.to_s) if new_record?
  end
end
