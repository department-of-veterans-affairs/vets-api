# frozen_string_literal: true

class Device < ApplicationRecord
  validates :key, presence: true
  validates :key, uniqueness: true
  validates :name, presence: true
  has_many :veteran_device_records, dependent: :destroy
  def self.veteran_device_records(user)
    active = Device.joins(:veteran_device_records)
                   .where(veteran_device_records: { icn: user.icn, active: true })
                   .select(:key, :name)
    {
      active:,
      inactive: Device.where.not(name: active.pluck(:name))
                      .select(:key, :name)
    }
  end
end
