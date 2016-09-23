# frozen_string_literal: true
class DisabilityClaimDetailSerializer < DisabilityClaimBaseSerializer
  attributes :contention_list, :va_representative,
             :phase_1_complete_date, :phase_2_complete_date,
             :phase_3_complete_date, :phase_4_complete_date,
             :phase_5_complete_date, :phase_6_complete_date,
             :phase_7_complete_date, :phase_8_complete_date

  def contention_list
    object.data['contentionList']
  end

  def phase_1_complete_date
    date_from_string 'claimPhaseDates', 'phase1CompleteDate'
  end

  def phase_2_complete_date
    date_from_string 'claimPhaseDates', 'phase2CompleteDate'
  end

  def phase_3_complete_date
    date_from_string 'claimPhaseDates', 'phase3CompleteDate'
  end

  def phase_4_complete_date
    date_from_string 'claimPhaseDates', 'phase4CompleteDate'
  end

  def phase_5_complete_date
    date_from_string 'claimPhaseDates', 'phase5CompleteDate'
  end

  def phase_6_complete_date
    date_from_string 'claimPhaseDates', 'phase6CompleteDate'
  end

  def phase_7_complete_date
    date_from_string 'claimPhaseDates', 'phase7CompleteDate'
  end

  def phase_8_complete_date
    date_from_string 'claimPhaseDates', 'phase8CompleteDate'
  end

  def va_representative
    object.data['poa']
  end
end
