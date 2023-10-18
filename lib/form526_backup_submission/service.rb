# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'common/exceptions/forbidden'
require 'common/exceptions/schema_validation_errors'
require 'benefits_intake_service/service'
require 'form526_backup_submission/configuration'

module Form526BackupSubmission
  ##
  # Proxy Service for the Lighthouse Claims Intake API Service.
  # We are using it here to submit claims that cannot be auto-established,
  # via paper submission (electronic PDF submissiont to CMP)
  #
  class Service < BenefitsIntakeService::Service
    configuration Form526BackupSubmission::Configuration

    def permanent_file?(file)
      file.include?('bdd_instructions.pdf')
    end
  end
end
