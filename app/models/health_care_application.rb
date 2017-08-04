# frozen_string_literal: true
class HealthCareApplication < ActiveRecord::Base
  validates(:state, presence: true)

  def set_success
  end
end
