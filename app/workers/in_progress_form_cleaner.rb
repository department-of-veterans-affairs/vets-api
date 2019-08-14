# frozen_string_literal: true

class InProgressFormCleaner
  include Sidekiq::Worker

  def perform
    forms = InProgressForm.where('expires_at < ?', Time.now.utc)
    logger.info("Deleting #{forms.count} old saved forms")
    forms.delete_all
  end
end
