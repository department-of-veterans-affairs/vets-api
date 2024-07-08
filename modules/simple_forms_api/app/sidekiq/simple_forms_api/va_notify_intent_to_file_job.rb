# frozen_string_literal: true

# This is a one-time job and it is not meant to be run after July 2024
# If you see this file in the code base after July 2024, it means that Eric Tillberg forgot to remove it
module SimpleFormsApi
  class VANotifyIntentToFileJob
    include Sidekiq::Job

    def perform(submission) # rubocop:disable Metrics/MethodLength
      icn = submission.user_account&.icn
      mpi_profile = MPI::Service.new.find_profile_by_identifier(identifier: icn, identifier_type: 'ICN')
      return unless mpi_profile.ok?

      first_name = mpi_profile.profile.given_names&.first
      return unless first_name

      template_id = '436a4756-e73f-499f-82cc-978649fd0c44'

      benefits = JSON.parse(submission.form_data)&.[]('benefit_selection')
      intent_to_file_benefits = if benefits['compensation'] && benefits['pension']
                                  'Disability Compensation (VA Form 21-526EZ) and Pension (VA Form 21P-527EZ)'
                                elsif benefits['compensation']
                                  'Disability Compensation (VA Form 21-526EZ)'
                                elsif benefits['pension']
                                  'Pension (VA Form 21P-527EZ)'
                                elsif benefits['survivor']
                                  'Survivors Pension and/or Dependency and Indemnity Compensation (DIC)' \
                                    ' (VA Form 21P-534 or VA Form 21P-534EZ)'
                                end

      benefits_intake_uuid = submission.benefits_intake_uuid

      personalisation = {
        'first_name' => first_name&.upcase,
        'confirmation_number' => benefits_intake_uuid,
        'date_submitted' => submission.created_at.strftime('%B %d, %Y'),
        'intent_to_file_benefits' => intent_to_file_benefits
      }

      Rails.logger.info('VaNotifyIntentToFileJob', benefits_intake_uuid:, date_submitted: submission.created_at,
                                                   intent_to_file_benefits:)
      VANotify::IcnJob.perform_async(icn, template_id, personalisation)
    end
  end
end
