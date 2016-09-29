# frozen_string_literal: true
class DisabilityClaimDetailSerializer < DisabilityClaimBaseSerializer
  attributes :contention_list, :va_representative,
             :updates

  def contention_list
    object.data['contentionList']
  end

  def va_representative
    object.data['poa']
  end

  def updates
    updates = [
      make_event(:filed, 'date'),
      make_event(:completed, 'claimCompleteDate')
    ]

    # Do the 8 phases
    (1..8).each { |n|
      updates << make_event("phase#{n}", 'claimPhaseDates', "phase#{n}CompleteDate")
    }

    updates.select! { |item| item[:date] }
    updates.sort! { |a,b| a[:date] <=> b[:date] }
  end

  private

  def make_event(type, *from_keys, extra: nil)
    {
      type: type,
      date: date_from_string(*from_keys),
      extra: extra
    }
  end

end
