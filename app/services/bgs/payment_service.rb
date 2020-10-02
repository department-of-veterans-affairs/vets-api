# frozen_string_literal: true

module BGS
  class PaymentService < BaseService
    def payment_history
      person = @service.people.find_person_by_ptcpnt_id(@user.participant_id)
      return { payments: [], return_payments: [] } if person.nil?

      response = @service.payment_information.retrieve_payment_summary_with_bdn(
        @user.participant_id,
        person[:file_nbr],
        '00',
        @user.ssn)
    rescue => e
      return { payments: [], return_payments: [] } if e.message.include?('No payment record found')

      report_error(e)
    end
  end
end
