# frozen_string_literal: true

module DebtManagementCenter
  class VaAwardsComposite
    include Virtus.model
    attribute :name, String
    attribute :amount, String
    attribute :veteran_or_spouse, String
  end
end

class FormProfiles::VA5655 < FormProfile
  attribute :va_awards_composite, DebtManagementCenter::VaAwardsComposite

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end

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
