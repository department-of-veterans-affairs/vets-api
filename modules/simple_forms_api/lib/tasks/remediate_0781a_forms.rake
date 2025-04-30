# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/form_0781_config'
require_relative '../../app/services/simple_forms_api/form_remediation/jobs/archive_batch_processing_job'

# Invoke this as follows:
#  Passing just form526_submission_ids (will use default type):
#    bundle exec rails simple_forms_api:remediate_0781a_forms[123 456]
#
# This task is specifically for remediating Form 0781A submissions
# from the dataset of affected claims (0781a_affected_claim_details).
#
# Related: https://github.com/department-of-veterans-affairs/va.gov-team/issues/xyz
# See also the companion task for 0781/0781v2 forms: remediate_0781_and_0781v2_forms.rake

def validate_input!(form526_submission_ids)
  raise Common::Exceptions::ParameterMissing, 'form526_submission_ids' unless form526_submission_ids&.any?
end

namespace :simple_forms_api do
  desc 'Remediate Form 0781A submissions via the ArchiveBatchProcessingJob'
  task :remediate_0781a_forms, %i[form526_submission_ids] => :environment do |_, args|
    form526_submission_ids = args[:form526_submission_ids].to_s.split(/[,\s]+/)
    type = :remediation

    begin
      validate_input!(form526_submission_ids)

      Rails.logger.info(
        "Starting ArchiveBatchProcessingJob for form 526 ids: #{form526_submission_ids.join(', ')} using type: #{type}"
      )

      # Call the service object synchronously and get the presigned URLs
      config = SimpleFormsApi::FormRemediation::Configuration::Form0781Config.new(form_key: 'form0781a')
      job = SimpleFormsApi::FormRemediation::Jobs::ArchiveBatchProcessingJob.new
      job.perform(ids: form526_submission_ids, config:, type: type.to_sym)

      Rails.logger.info('Task successfully completed.')
    rescue Common::Exceptions::ParameterMissing => e
      raise e
    rescue => e
      Rails.logger.error("Error occurred while archiving submissions: #{e.message}")
      puts 'An error occurred. Check logs for more details.'
    end
  end
end
