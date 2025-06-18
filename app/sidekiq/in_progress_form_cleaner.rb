# frozen_string_literal: true

class InProgressFormCleaner
  include Sidekiq::Job

  def perform
    forms = InProgressForm.where('expires_at < ?', Time.now.utc)

    ['28-1900', '28-1900_V2'].each do |form_id|
      count = forms.where(form_id: form_id).count
      StatsD.increment("worker.in_progress_form_cleaner.#{form_id.downcase.tr('-', '_')}_deleted", count) if count > 0
    end

    logger.info("Deleting #{forms.count} old saved forms")
    forms.delete_all
  end
end
