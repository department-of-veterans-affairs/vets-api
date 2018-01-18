# frozen_string_literal: true

class MaintenanceWindow < ActiveRecord::Base
  scope :end_after, ->(time) { where('end_time > ?', time) }
end
