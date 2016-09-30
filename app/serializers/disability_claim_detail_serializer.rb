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
      create_event_from_string_date(:filed, 'date'),
      create_event_from_string_date(:completed, 'claimCompleteDate'),
      create_event_from_yes_no(:development_letter_sent, 'developmentLetterSent'),
      create_event_from_yes_no(:decision_notification_sent, 'decisionNotificationSent'),
      create_event_from_bool(:requested_decision, 'waiver5103Submitted')
    ]

    # Do the 8 phases
    (1..8).each do |n|
      updates << create_event_from_string_date("phase#{n}", 'claimPhaseDates', "phase#{n}CompleteDate")
    end

    list_objects_with_key(["claimTrackedItems", "stillNeedFromYouList"], ["openedDate"]) do |obj|
      updates << {
        type: :requested_item,
        date: Date.strptime(obj["openedDate"], '%m/%d/%Y'),
        description: obj['description']
      }
    end

    # Filter out events that were nil and make reverse chron
    updates.compact.sort_by{ |h| h[:date] }.reverse

  end

  private

  def create_event_from_string_date(type, *from_keys)
    date = date_from_string(*from_keys)
    return nil unless date
    {
      type: type,
      date: date
    }
  end

  # Some states in the updates timeline are sent to us as just strings/booleans
  # without a date associated with it. If they haven't been seen by
  # vets-api before, we'll say that it happened today, so it shows up at
  # the top of the timeline.
  def create_event_from_yes_no(type, *from_keys)
    return nil unless bool_from_yes_no(*from_keys)
    {
      type: type,
      date: Time.current.to_date()
    }
  end

  def create_event_from_bool(type, *from_keys)
    date = date_from_string(*from_keys)
    return nil unless object.data.dig(*from_keys)
    {
      type: type,
      date: Time.current.to_date()
    }
  end
end
