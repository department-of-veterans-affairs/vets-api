# frozen_string_literal: true

# Ensure the all the handlers are registered for BenefitsIntake::SubmissionStatusJob

# require_all uses application root, not autoload paths
require_all 'lib/lighthouse/benefits_intake/submission_handler'

require 'lighthouse/benefits_intake/sidekiq/submission_status_job'

# Registers handlers for various form IDs
# @see modules/burials
# @see modules/pensions
{}.each do |form_id, handler_class|
  BenefitsIntake::SubmissionStatusJob.register_handler(form_id, handler_class)
end
