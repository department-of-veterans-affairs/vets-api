# frozen_string_literal: true

module DebtManagementCenter
  class Payments
    def initialize(current_user)
      @person = BGS::PeopleService.new(current_user).find_person_by_participant_id
      @payments = BGS::PaymentService.new(current_user).payment_history(@person)['payments']['payment']
    end

    def compensation_and_pension
      select_payments :compensation
    end

    def education
      select_payments :education
    end

    private

    def select_payments(type)
      type = if type == :compensation
               'Compensation & Pension - Recurring'
             elsif type == :education
               'Education'
             end

      @payments.select { |payment| payment['payment_type'] == type }

      if @payments.empty?
        nil
      else
        @payments.sort { |a, b| a['payment_date'] <=> b['payment_date'] }
      end
    end
  end
end
