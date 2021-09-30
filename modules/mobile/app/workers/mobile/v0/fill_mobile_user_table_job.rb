# frozen_string_literal: true

require 'sidekiq'

module Mobile
  module V0
    class FillMobileUserTableJob
      include Sidekiq::Worker

      sidekiq_options(retry: false)

      def perform(icn)
        resource = Mobile::V0::Users.new(icn: icn)
        resource.save!
        Rails.logger.info('Mobile user table add succeeded for user with icn ', { icn: icn })
      rescue => e
        Rails.logger.error('Mobile user table add failed for user with icn ', { icn: icn })
        raise e
      end
    end
  end
end
