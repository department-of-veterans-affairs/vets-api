# frozen_string_literal: true

require 'rails_helper'

require 'kafka/sidekiq/event_bus_submission_job'
require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_intake/metadata'
require 'lighthouse/benefits_intake/sidekiq/submit_claim_job'

Rspec.describe BenefitsIntake::SubmissionStatusJob, type: :job do

end
