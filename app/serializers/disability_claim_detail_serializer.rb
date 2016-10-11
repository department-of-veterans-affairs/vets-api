# frozen_string_literal: true
class DisabilityClaimDetailSerializer < DisabilityClaimBaseSerializer
  attributes :contention_list, :va_representative, :events_timeline

  def contention_list
    object.data['contentionList']
  end

  def va_representative
    object.data['poa']
  end

  def events_timeline
    events = [
      create_event_from_string_date(:filed, 'date'),
      create_event_from_string_date(:completed, 'claimCompleteDate')
    ]

    # Do the 8 phases
    (1..8).each do |n|
      events << create_event_from_string_date(
        "phase#{n}", 'claimPhaseDates', "phase#{n}CompleteDate"
      )
    end

    # Add tracked items
    events += create_events_for_tracked_items

    # Make reverse chron with nil date items at the end
    events.compact.sort_by { |h| h[:date] || Date.new }.reverse
  end

  def phase
    phase_from_keys 'claimPhaseDates', 'latestPhaseType'
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

  TRACKED_ITEM_FIELDS = %w(
    neverReceivedFromOthersList neverReceivedFromYouList
    receivedFromOthersList receivedFromYouList stillNeedFromYouList
  ).freeze

  def create_events_for_tracked_items
    TRACKED_ITEM_FIELDS.map do |field|
      sub_objects_of('claimTrackedItems', field).map do |obj|
        create_tracked_item_event(field.snakecase, obj)
      end
    end.flatten
  end

  def create_tracked_item_event(type, obj)
    event = {
      type: type,
      tracked_item_id: obj['trackedItemId'],
      description: obj['description'],
      display_name: obj['displayedName'],
      overdue: obj['overdue'],
      status: obj['trackedItemStatus'],
      uploaded: obj['uploaded'],
      uploads_allowed: obj['uploadsAllowed'],
      opened_date: date_or_nil_from(obj, 'openedDate'),
      requested_date: date_or_nil_from(obj, 'requestedDate'),
      received_date: date_or_nil_from(obj, 'receivedDate'),
      closed_date: date_or_nil_from(obj, 'closedDate'),
      suspense_date: date_or_nil_from(obj, 'suspenseDate')
    }
    event[:date] = [
      event[:opened_date], event[:requested_date], event[:received_date],
      event[:closed_date], event[:suspense_date]
    ].compact.first
    event
  end

  def sub_objects_of(*parents)
    items = object.data.dig(*parents) || []
    items.compact
  end

  def date_or_nil_from(obj, key)
    date = obj[key]
    return nil unless date.present?
    Date.strptime(date, '%m/%d/%Y')
  end
end
