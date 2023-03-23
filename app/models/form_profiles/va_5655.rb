# frozen_string_literal: true

require 'debt_management_center/models/payment'
require 'debt_management_center/payments_service'

##
# Form Profile for VA Form 5655, the Financial Status Report Form
#
class FormProfiles::VA5655 < FormProfile
  attribute :payments, DebtManagementCenter::Payment

  ##
  # Overrides the FormProfile metadata method, to provide frontend with usable metadata
  #
  # @return [Hash]
  #
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end

  ##
  # Overrides the FormProfile prefill method to initialize @va_awards_composite
  #
  # @return [Hash]
  #
  def prefill
    @payments = init_payments
    super
  end

  private

  def va_file_number_last_four
    return unless user.authorize :debt, :access?

    file_number =
      begin
        response = BGS::People::Request.new.find_person_by_participant_id(user:)
        response.file_number.presence || user.ssn
      rescue
        user.ssn
      end

    file_number&.last(4)
  end

  def init_payments
    return {} unless user.authorize :debt, :access?

    payments = DebtManagementCenter::PaymentsService.new(user)

    DebtManagementCenter::Payment.new(
      education_amount: payment_amount(payments.education),
      compensation_amount: payment_amount(payments.compensation_and_pension),
      veteran_or_spouse: 'VETERAN'
    )
  end

  def payment_amount(payments)
    last_month = Time.zone.today - 30.days

    # Filter to only use recent payments from last 30 days
    payments&.select { |payment| Date.parse(payment[:payment_date].to_s) > last_month }&.last&.[](:payment_amount)
  end
end
