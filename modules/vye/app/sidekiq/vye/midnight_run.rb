# frozen_string_literal: true

module Vye
  class MidnightRun
    include Sidekiq::Worker

    def perform
      Rails.logger.info 'Vye::MidnightRun starting'
      IngressBdn.perform_async
      Rails.logger.info 'Vye::MidnightRun finished'
    end
  end
end
