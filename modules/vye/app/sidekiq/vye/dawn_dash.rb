# frozen_string_literal: true

module Vye
  class DawnDash
    include Sidekiq::Worker

    def perform
      Rails.logger.info 'Vye::DawnDash starting'
      ActivateBdn.perform_async
      Rails.logger.info 'Vye::DawnDash finished'
    end
  end
end
