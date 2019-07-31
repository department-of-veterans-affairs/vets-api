# frozen_string_literal: true

class MaintenanceWindow < ApplicationRecord
  scope :end_after, ->(time) { where('end_time > ?', time) }
end
