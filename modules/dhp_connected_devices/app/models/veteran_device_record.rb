# frozen_string_literal: true

class VeteranDeviceRecord < ApplicationRecord
  validates :icn, :device_id, presence: true
  belongs_to :device
  before_validation :validate_unique_ids, on: :create

  def self.active_devices(user)
    VeteranDeviceRecord.where(icn: user.icn, active: true)
  end

  def validate_unique_ids
    if VeteranDeviceRecord.find_by(device_id:, icn:).nil?
      nil
    else
      errors.add(:icn, 'User already associated with provided device_id')
    end
  end
end
