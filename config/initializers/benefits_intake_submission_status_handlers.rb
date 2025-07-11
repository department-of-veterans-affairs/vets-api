# frozen_string_literal: true

# Lazy load handlers to avoid loading during boot
Rails.application.reloader.to_prepare do
  # Only load handlers when actually needed
  next unless Rails.env.test? || ENV['LOAD_SUBMISSION_HANDLERS'] == 'true'
  
  # require_all uses application root, not autoload paths
  require_all 'lib/lighthouse/benefits_intake/submission_handler'
  require 'lighthouse/benefits_intake/sidekiq/submission_status_job'

  # Registers handlers for various form IDs
  # @see modules/burials
  # @see modules/pensions
  {}.each do |form_id, handler_class|
    BenefitsIntake::SubmissionStatusJob.register_handler(form_id, handler_class)
  end
end
