# frozen_string_literal: true

module BGS
  class PaymentService < BaseService
    def payment_history(person)
      return { payments: [], return_payments: [] } if person.blank?

      response = @service.payment_information.retrieve_payment_summary_with_bdn(
        person[:ptcpnt_id],
        person[:file_nbr],
        '00', # payee code
        person[:ssn_nbr]
      )

      return { payments: [], return_payments: [] } if response[:payments].nil?

      response
    rescue => e
      report_error(e)
      { payments: [], return_payments: [] } if e.message.include?('No Data Found')
    end
  end
end
