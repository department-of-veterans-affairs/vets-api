# frozen_string_literal: true

class LoadAverageDaysForClaimCompletionJob
  include Sidekiq::Job

  def perform
    puts("Running LoadAverageDaysForClaimCompletionJob")
    logger.info("Performing LoadAverageDaysForClaimCompletionJob")
    # forms = InProgressForm.where('expires_at < ?', Time.now.utc)
    # logger.info("Deleting #{forms.count} old saved forms")
    # forms.delete_all
  end
end
