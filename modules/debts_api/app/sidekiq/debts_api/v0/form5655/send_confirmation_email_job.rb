require 'debts_api/v0/financial_status_report_service'

module DebtsApi
  class V0::Form5655::SendConfirmationEmailJob
    def perform(args)
      if submissions.blank?
        Rails.logger.warn(
          "DebtsApi::SendConfirmationEmailJob - No submissions found for user_uuid: #{args['user_uuid']}"
        )
        return
      end

      DebtManagementCenter::VANotifyEmailJob.perform_async(
        args['email'], args['template_id'], email_personalization_info(args), { id_type: 'email' }
      )
    end

    private

    def email_personalization_info(args)
      form_submissions = submissions(args['user_uuid'])
      confirmation_numbers = form_submissions.map(&:id)
      {
        'first_name' => args['first_name'],
        'date_submitted' => Time.zone.now.strftime('%m/%d/%Y'),
        'confirmation_number' => confirmation_numbers
      }
    end

    def submissions(user_uuid)
      DebtsApi::V0::Form5655Submission.where(user_uuid: user_uuid, state: 'in_progress')
    end
  end
end
