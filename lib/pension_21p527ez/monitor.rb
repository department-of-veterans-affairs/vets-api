# frozen_string_literal: true

module Pension21p527ez
  class Monitor
    STATS_KEY = 'api.pension_claim'

    def track_show404(confirmation_number, current_user, e)
      Rails.logger.error('21P-527EZ submission not found',
                         { confirmation_number:, user_uuid: current_user&.uuid, message: e&.message })
    end

    def track_show_error(confirmation_number, current_user, e)
      Rails.logger.error('21P-527EZ fetching submission failed',
                         { confirmation_number:, user_uuid: current_user&.uuid, message: e&.message })
    end

    def track_create_attempt(claim, current_user)
      StatsD.increment("#{STATS_KEY}.attempt")
      Rails.logger.info('21P-527EZ submission to Sidekiq begun',
                        { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid })
    end

    def track_create_error(in_progress_form, claim, current_user, e = nil)
      StatsD.increment("#{STATS_KEY}.failure")
      Rails.logger.error('21P-527EZ submission to Sidekiq failed',
                         { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid,
                           in_progress_form_id: in_progress_form&.id, errors: claim&.errors&.errors,
                           message: e&.message })
    end

    def track_create_success(in_progress_form, claim, current_user)
      StatsD.increment("#{STATS_KEY}.success")
      Rails.logger.info('21P-527EZ submission to Sidekiq success',
                        { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid,
                          in_progress_form_id: in_progress_form&.id })
    end
  end
end
