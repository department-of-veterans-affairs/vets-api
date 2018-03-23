# frozen_string_literal: true

class PensionBurialNotifications
  include Sidekiq::Worker

  def perform
    binding.pry
  end
end
