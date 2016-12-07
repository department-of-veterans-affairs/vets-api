# frozen_string_literal: true
class DisabilityClaimDetailSerializer < DisabilityClaimBaseSerializer
  attributes :contention_list, :va_representative, :events_timeline, :claim_type

  def contention_list
    object.data['contention_list']
  end

  def va_representative
    object.data['poa']
  end

  def claim_type
    object.data['status_type']
  end

  def events_timeline
    events = [
      create_event_from_string_date(:filed, 'date'),
      create_event_from_string_date(:completed, 'claim_complete_date')
    ]

    # Do the 8 phases
    (1..8).each do |n|
      events << create_event_from_string_date(
        "phase#{n}", 'claim_phase_dates', "phase#{n}_complete_date"
      )
    end

    # Add tracked items
    events += create_events_for_tracked_items

    # Add documents not associated with a tracked item
    events += create_events_for_documents

    # Make reverse chron with nil date items at the end
    events.compact.sort_by { |h| h[:date] || Date.new }.reverse
  end

  def phase
    phase_from_keys 'claim_phase_dates', 'latest_phase_type'
  end

  private

  def object_data
    object.data
  end

  def create_event_from_string_date(type, *from_keys)
    date = object.data.dig(*from_keys)
    return nil unless date
    {
      type: type,
      date: Date.strptime(date, '%m/%d/%Y')
    }
  end

  TRACKED_ITEM_FIELDS = %w(
    never_received_from_others_list never_received_from_you_list received_from_others_list
    received_from_you_list still_need_from_you_list still_need_from_others_list
  ).freeze

  def create_events_for_tracked_items
    TRACKED_ITEM_FIELDS.map do |field|
      sub_objects_of('claim_tracked_items', field).map do |obj|
        create_tracked_item_event(field.underscore, obj)
      end
    end.flatten
  end

  def create_events_for_documents
    # Objects with trackedItemId are part of other events, so don't duplicate them
    docs = sub_objects_of('vba_document_list').select { |obj| obj['tracked_item_id'].nil? }
    docs = create_documents docs
    docs.map do |obj|
      obj.merge(type: :other_documents_list, date: obj[:upload_date])
    end
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
      tracked_item_id: obj['tracked_item_id'],
      description: ActionView::Base.full_sanitizer.sanitize(obj['description']),
      display_name: obj['displayed_name'],
      overdue: obj['overdue'],
      status: obj['tracked_item_status'],
      uploaded: obj['uploaded'],
      uploads_allowed: obj['uploads_allowed'],
      opened_date: date_or_nil_from(obj, 'opened_date'),
      requested_date: date_or_nil_from(obj, 'requested_date'),
      received_date: date_or_nil_from(obj, 'received_date'),
      closed_date: date_or_nil_from(obj, 'closed_date'),
      suspense_date: date_or_nil_from(obj, 'suspense_date'),
      documents: create_documents(obj['vba_documents'] || [])
    }
    event[:date] = event.slice(*EVENT_DATE_FIELDS).values.compact.first
    event
  end

  def create_documents(objs)
    objs.map do |obj|
      {
        tracked_item_id: obj['tracked_item_id'],
        file_type: obj['document_type_label'],
        document_type: obj['document_type_code'],
        filename: obj['original_file_name'],
        # %Q is the C-strftime flag for milliseconds since Unix epoch.
        # For date-times recording a computer event and therefore known
        # to the second EVSS uses a UNIX timestamp in milliseconds.
        # Round it to the day. Not sure what timezone they're using,
        # so could be off by 1 day.
        upload_date: date_or_nil_from(obj, 'upload_date', format: '%Q')
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
