# frozen_string_literal: true

module BGS
  class PaymentService < BaseService
    def payment_history(person)
      response = @service.payment_information.retrieve_payment_summary_with_bdn(
        person.participant_id,
        person.file_number,
        '00', # payee code
        person.ssn_number
      )
      return empty_response if response[:payments].nil?

      response
    rescue => e
      report_error(e)
      empty_response if e.message.include?('No Data Found')
    end

    private

    def empty_response
      { payments: { payment: [] } }
    end
  end
end
