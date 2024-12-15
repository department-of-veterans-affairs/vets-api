# frozen_string_literal: true

module Vye
  class MidnightRun
    include Sidekiq::Worker

    def perform
      logger.info('Vye::MidnightRun starting')
      IngressBdn.perform_async
      logger.info('Vye::MidnightRun finished')
    end
  end
end
