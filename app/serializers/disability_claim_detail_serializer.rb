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

    # Filter out events that were nil and make reverse chron
    events.compact.sort_by { |h| h[:date] }.reverse
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
    events = []
    TRACKED_ITEM_FIELDS.each do |field|
      list_objects_with_key(['claimTrackedItems', field], ['openedDate']).each do |obj|
        date = obj['openedDate'] || obj['receivedDate']
        events << {
          type: field.snakecase,
          date: Date.strptime(date, '%m/%d/%Y'),
          description: obj['description'],
          display_name: obj['displayedName'],
          overdue: obj['overdue'],
          tracked_item_id: obj['trackedItemId'],
          tracked_item_status: obj['trackedItemStatus']
        } if date
      end
    end
    events
  end

  def list_objects_with_key(parents, sub_keys)
    parent = object.data.dig(*parents)
    parent = [] if parent.blank?
    parent.each do |obj|
      val = obj.dig(*sub_keys)
      obj if val.present?
    end.compact
  end
end
