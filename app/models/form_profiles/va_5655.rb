# frozen_string_literal: true

require 'debt_management_center/models/va_awards_composite'

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
    @va_awards_composite = init_va_awards
    super
  end

  private

  def va_file_number_last_four
    (
      BGS::PeopleService.new(user).find_person_by_participant_id[:file_nbr].presence ||
        user.ssn.presence
    )&.last(4)
  end

  def init_va_awards
    awards = BGS::AwardsService.new(user)

    DebtManagementCenter::VaAwardsComposite.new(
      name: 'VA Benefits',
      amount: awards.gross_amount,
      veteran_or_spouse: 'VETERAN'
    )
  end
end
