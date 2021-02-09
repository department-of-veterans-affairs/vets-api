# frozen_string_literal: true

require 'debt_management_center/models/va_awards_composite'
require 'debt_management_center/payments_service'

##
# Form Profile for VA Form 5655, the Financial Status Report Form
#
class FormProfiles::VA5655 < FormProfile
  attribute :va_awards_composite, DebtManagementCenter::VaAwardsComposite

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
    (
      BGS::PeopleService.new(user).find_person_by_participant_id[:file_nbr].presence ||
        user.ssn.presence
    )&.last(4)
  end

  def init_payments
    payments = DebtManagementCenter::Payments.new(user)

    {
      veteran_or_spouse: 'VETERAN',
      compensation_amount: payments.compensation_and_pension.last['payment_amount'],
      education_amount: payments.education.last['payment_amount']
    }
  end
end
