# frozen_string_literal: true

module DebtManagementCenter
  class PaymentsService
    include SentryLogging

    def initialize(current_user)
      @person =
        begin
          BGS::PeopleService.new(current_user).find_person_by_participant_id.presence || {}
        rescue => e
          report_error(e, current_user)
          {}
        end

      @payments =
        begin
          BGS::PaymentService.new(current_user).payment_history(@person)[:payments][:payment].presence || []
        rescue => e
          report_error(e, current_user)
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

    def report_error(error, user)
      log_exception_to_sentry(
        error,
        {
          icn: user.icn
        },
        { team: 'vfs-debt' }
      )
    end
  end
end
