# frozen_string_literal: true

class InProgressFormCleaner
  include Sidekiq::Job

  def perform
    forms = InProgressForm.where('expires_at < ?', Time.now.utc)

    form_counts = forms.group(:form_id).count
    form_counts.each do |form_id, count|
      if count.positive?
        StatsD.increment("worker.in_progress_form_cleaner.#{form_id.downcase.tr('-', '_')}_deleted", count)
      end
    end

    logger.info("Deleting #{forms.count} old saved forms")
    forms.delete_all
  end
end
