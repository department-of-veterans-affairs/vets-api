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
      make_string_dated_event(:filed, 'date'),
      make_string_dated_event(:completed, 'claimCompleteDate'),
      check_for_yes_no_event(:development_letter_sent, 'developmentLetterSent'),
      check_for_yes_no_event(:decision_notification_sent, 'decisionNotificationSent'),
      check_for_bool_event(:requested_decision, 'waiver5103Submitted')
    ]

    # Do the 8 phases
    (1..8).each { |n|
      updates << make_string_dated_event("phase#{n}", 'claimPhaseDates', "phase#{n}CompleteDate")
    }

    # Filter out events that were nil
    updates.select! { |item| item[:date] }

    # Reverse chron
    updates.sort! { |a,b| b[:date] <=> a[:date] }
  end

  private

  def make_string_dated_event(type, *from_keys, extra: nil)
    {
      type: type,
      date: date_from_string(*from_keys),
      extra: extra
    }
  end

  # Some states in the updates timeline are sent to us as just strings/booleans
  # without a date associated with it. If they haven't been seen by
  # vets-api before, we'll say that it happened today, so it shows up at
  # the top of the timeline.
  def check_for_yes_no_event(type, *from_keys)
    {
      type: type,
      date: (Time.current.to_date() if bool_from_yes_no(*from_keys))
    }
  end

  def check_for_bool_event(type, *from_keys)
    {
      type: type,
      date: (Time.current.to_date() if object.data.dig(*from_keys))
    }
  end
end
