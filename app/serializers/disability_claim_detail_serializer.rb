# frozen_string_literal: true
class DisabilityClaimDetailSerializer < DisabilityClaimBaseSerializer
  attributes :contention_list, :va_representative, :events_timeline, :claim_type

  def contention_list
    object.data['contentionList']
  end

  def va_representative
    object.data['poa']
  end

  def claim_type
    object.data['statusType']
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

  # Order of EVENT_DATE_FIELDS determines which date trumps in timeline sorting
  EVENT_DATE_FIELDS = %i(
    closed_date
    received_date
    opened_date
    requested_date
    suspense_date
  ).freeze

  def create_tracked_item_event(type, obj)
    event = {
      type: type,
      tracked_item_id: obj['trackedItemId'],
      description: ActionView::Base.full_sanitizer.sanitize(obj['description']),
      display_name: obj['displayedName'],
      overdue: obj['overdue'],
      status: obj['trackedItemStatus'],
      uploaded: obj['uploaded'],
      uploads_allowed: obj['uploadsAllowed'],
      opened_date: date_or_nil_from(obj, 'openedDate'),
      requested_date: date_or_nil_from(obj, 'requestedDate'),
      received_date: date_or_nil_from(obj, 'receivedDate'),
      closed_date: date_or_nil_from(obj, 'closedDate'),
      suspense_date: date_or_nil_from(obj, 'suspenseDate'),
      documents: create_documents(obj['vbaDocuments'] || [])
    }
    event[:date] = event.slice(*EVENT_DATE_FIELDS).values.compact.first
    event
  end

  def create_documents(objs)
    objs.map do |obj|
      {
        tracked_item_id: obj['trackedItemId'],
        file_type: obj['documentTypeLabel'],
        document_type: obj['documentTypeCode'],
        filename: obj['originalFileName'],
        # %Q is the C-strftime flag for milliseconds since Unix epoch.
        # For date-times recording a computer event and therefore known
        # to the second EVSS uses a UNIX timestamp in milliseconds.
        # Round it to the day. Not sure what timezone they're using,
        # so could be off by 1 day.
        upload_date: date_or_nil_from(obj, 'uploadDate', format: '%Q')
      }
    end
  end

  def sub_objects_of(*parents)
    items = object.data.dig(*parents) || []
    items.compact
  end

  def date_or_nil_from(obj, key, format: '%m/%d/%Y')
    date = obj[key]
    return nil unless date.present?
    Date.strptime(date.to_s, format)
  end
end
