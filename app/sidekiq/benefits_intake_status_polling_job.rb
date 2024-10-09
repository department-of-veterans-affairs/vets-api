# frozen_string_literal: true

require 'benefits_intake_service/service'

class BenefitsIntakeStatusPollingJob
  include Sidekiq::Job
  sidekiq_options retry: false

  STATS_KEY = 'api.benefits_intake.polled_status'
  MAX_BATCH_SIZE = 1000
  attr_reader :max_batch_size

  def initialize(max_batch_size: MAX_BATCH_SIZE)
    @max_batch_size = max_batch_size
    @total_handled = 0
  end

  def perform
    Rails.logger.info('Beginning Form 526 Intake Status polling')
    submissions.in_batches(of: max_batch_size) do |batch|
      batch_ids = batch.pluck(:backup_submitted_claim_id).flatten
      response = api_to_poll.get_bulk_status_of_uploads(batch_ids)
      handle_response(response)
    end
    Rails.logger.info('Form 526 Intake Status polling complete',
                      total_handled: @total_handled)
  rescue => e
    Rails.logger.error('Error processing 526 Intake Status batch',
                       class: self.class.name, message: e.message)
  end

  private

  def api_to_poll
    @api_to_poll ||= BenefitsIntakeService::Service.new
  end

  def submissions
    raise NotImplementedError, "Required submissions records method not implimented. Impliment a `#{self.class.name}.submissions` method."
  end

end
