# frozen_string_literal: true

# Ensure the all the handlers are registered for BenefitsIntake::SubmissionStatusJob

# require_all uses application root, not autoload paths
require_all 'lib/lighthouse/benefits_intake/submission_handler'

require 'lighthouse/benefits_intake/sidekiq/submission_status_job'

require 'dependents/benefits_intake/submission_handler'
require 'pcpg/benefits_intake/submission_handler'
require 'vre/benefits_intake/submission_handler'

# Registers handlers for various form IDs
# @see modules/burials
# @see modules/pensions
{
  '686C-674' => Dependents::BenefitsIntake::SubmissionHandler,
  '28-8832' => PCPG::BenefitsIntake::SubmissionHandler,
  '28-1900' => VRE::BenefitsIntake::SubmissionHandler
}.each do |form_id, handler_class|
  BenefitsIntake::SubmissionStatusJob.register_handler(form_id, handler_class)
end
