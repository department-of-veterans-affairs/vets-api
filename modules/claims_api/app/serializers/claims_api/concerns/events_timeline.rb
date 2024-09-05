# frozen_string_literal: true

module ClaimsApi
  module Concerns
    module EventsTimeline
      extend ActiveSupport::Concern

      TRACKED_ITEM_FIELDS = %w[
        never_received_from_others_list never_received_from_you_list received_from_others_list
        received_from_you_list still_need_from_you_list still_need_from_others_list
      ].freeze

      EVENT_DATE_FIELDS = %i[
        closed_date received_date upload_date opened_date requested_date suspense_date
      ].freeze

      included do
        attribute :events_timeline do |object|
          events_timeline(object)
        end

        def self.events_timeline(object)
          events = [
            create_event_from_string_date(object, :filed, 'date'),
            create_event_from_string_date(object, :completed, 'claim_complete_date')
          ]

          (1..8).each do |n|
            events << create_event_from_string_date(
              object, "phase#{n}", 'claim_phase_dates', "phase#{n}_complete_date"
            )
          end

          events += create_events_for_tracked_items(object)
          events += create_events_for_documents(object)
          events.compact.sort_by { |h| h[:date] || Date.new }.reverse
        end
      end

      class_methods do
        def create_event_from_string_date(object, type, *keys)
          date = object_data(object).dig(*keys)
          return nil unless date

          { type:, date: Date.strptime(date, '%m/%d/%Y') }
        end

        def create_events_for_tracked_items(object)
          TRACKED_ITEM_FIELDS.flat_map do |field|
            sub_objects_of(object, 'claim_tracked_items', field).map do |obj|
              create_tracked_item_event(object, field.underscore, obj)
            end
          end
        end

        def create_events_for_documents(object)
          docs = sub_objects_of(object, 'vba_document_list').select { |obj| obj['tracked_item_id'].nil? }
          create_documents(docs).map { |obj| obj.merge(type: :other_documents_list, date: obj[:upload_date]) }
        end

        def create_tracked_item_event(_object, type, obj)
          documents = create_documents(obj['vba_documents'] || [])
          event = {
            type:,
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
            documents:,
            upload_date: latest_upload_date(documents)
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
              upload_date: date_or_nil_from(obj, 'upload_date', format: '%Q')
            }
          end
        end

        def sub_objects_of(object, *keys)
          items = object_data(object).dig(*keys) || []
          items.compact
        end

        def date_or_nil_from(obj, key, format: '%m/%d/%Y')
          date = obj[key]
          return nil if date.blank?

          Date.strptime(date.to_s, format)
        end

        def latest_upload_date(documents)
          documents.pluck(:upload_date).sort.reverse.first
        end
      end
    end
  end
end
