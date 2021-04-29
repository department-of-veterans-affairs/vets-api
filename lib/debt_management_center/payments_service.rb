# frozen_string_literal: true

module DebtManagementCenter
  class PaymentsService
    def initialize(current_user)
      @person =
        begin
          BGS::PeopleService.new(current_user).find_person_by_participant_id.presence || {}
        rescue Savon::SOAPFault
          {}
        end

      @payments =
        begin
          BGS::PaymentService.new(current_user).payment_history(@person)[:payments][:payment].presence || []
        rescue Savon::SOAPFault
          []
        end
    end

    def compensation_and_pension
      select_payments :compensation
    end

    def education
      select_payments :education
    end

    private

    def select_payments(type)
      return nil if @payments.blank?

      type = if type == :compensation
               'Compensation & Pension - Recurring'
             elsif type == :education
               'Post-9/11 GI Bill'
             end

      selected_payments = @payments.select { |payment| payment[:payment_type] == type }

      if selected_payments.empty?
        nil
      else
        selected_payments.sort { |a, b| a[:payment_date] <=> b[:payment_date] }
      end
    end
  end
end
