# frozen_string_literal: true

class InProgressFormCleaner
  include Sidekiq::Worker

  def perform
    Sentry::TagRainbows.tag
    forms = InProgressForm.where("updated_at < '#{InProgressForm::EXPIRES_AFTER.ago}'")
    logger.info("Deleting #{forms.count} old saved forms")
    forms.delete_all
  end
end
