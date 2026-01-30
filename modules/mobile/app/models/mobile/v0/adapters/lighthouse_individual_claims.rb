# frozen_string_literal: true

require 'benefits_claims/title_generator'

module Mobile
  module V0
    module Adapters
      class LighthouseIndividualClaims
        # Order of EVENT_DATE_FIELDS determines which date trumps in timeline sorting.
        EVENT_DATE_FIELDS = %i[
          closed_date
          received_date
          upload_date
          opened_date
          requested_date
          suspense_date
        ].freeze

        # Lighthouse only provides tracked item status which does not match 1-1 to evss tracked item types.
        # We're forced here to coerce the status into a type that may not necessarily be true. but will behave
        # identically in the app. All received statuses are set to received_from_you_list when they could have actually
        # been received_from_others_list type.
        LH_STATUS_TO_EVSS_TYPE = {
          ACCEPTED: 'received_from_you_list',
          INITIAL_REVIEW_COMPLETE: 'received_from_you_list',
          NEEDED_FROM_YOU: 'still_need_from_you_list',
          NEEDED_FROM_OTHERS: 'still_need_from_others_list',
          NO_LONGER_REQUIRED: 'received_from_you_list',
          SUBMITTED_AWAITING_REVIEW: 'received_from_you_list'
        }.freeze

        LH_STATUS_TO_EVSS_STATUS = {
          ACCEPTED: 'NO_LONGER_REQUIRED',
          INITIAL_REVIEW_COMPLETE: 'NO_LONGER_REQUIRED',
          NEEDED_FROM_YOU: 'NEEDED',
          NEEDED_FROM_OTHERS: 'NEEDED',
          NO_LONGER_REQUIRED: 'NO_LONGER_REQUIRED',
          SUBMITTED_AWAITING_REVIEW: 'NEEDED'
        }.freeze

        UPLOADED_STATUSES = %w[ACCEPTED INITIAL_REVIEW_COMPLETE SUBMITTED_AWAITING_REVIEW].freeze

        DEFAULT_DATE = Date.new

        # rubocop:disable Metrics/MethodLength
        def parse(claim)
          return nil unless claim

          attributes = claim.dig('data', 'attributes')
          phase_change_date = attributes.dig('claimPhaseDates', 'phaseChangeDate')
          events_timeline = events_timeline(attributes)
          download_eligible_documents = collect_download_eligible_documents(events_timeline)

          claim_type = attributes['claimType']
          claim_type_code = attributes['claimTypeCode']

          use_generated_titles = Flipper.enabled?(Mobile::V0::Adapters::ClaimsOverview::FEATURE_USE_TITLE_GENERATOR_MOBILE)
          titles = BenefitsClaims::TitleGenerator.generate_titles(claim_type, claim_type_code)

          Mobile::V0::Claim.new(
            {
              id: claim['data']['id'],
              date_filed: attributes['claimDate'],
              min_est_date: attributes['minEstClaimDate'],
              max_est_date: attributes['maxEstClaimDate'],
              phase_change_date:,
              open: attributes['closeDate'].nil?,
              waiver_submitted: attributes['evidenceWaiverSubmitted5103'],
              documents_needed: attributes['documentsNeeded'],
              development_letter_sent: attributes['developmentLetterSent'],
              decision_letter_sent: attributes['decisionLetterSent'],
              phase: Mobile::ClaimsHelper.phase_to_number(attributes.dig('claimPhaseDates', 'latestPhaseType')),
              ever_phase_back: nil,
              current_phase_back: attributes.dig('claimPhaseDates', 'currentPhaseBack'),
              requested_decision: attributes['evidenceWaiverSubmitted5103'],
              claim_type:,
              contention_list: attributes['contentions'].pluck('name'),
              va_representative: nil,
              events_timeline:,
              updated_at: nil,
              claim_type_code:,
              claim_type_base: titles[:claim_type_base],
              display_title: use_generated_titles ? titles[:display_title] : nil,
              download_eligible_documents:
            }
          )
        end
        # rubocop:enable Metrics/MethodLength

        private

        def events_timeline(attributes)
          events = [
            create_event_from_string_date(:filed, attributes['claimDate']),
            create_event_from_string_date(:completed, attributes['closeDate'])
          ]

          # Do the 8 phases
          (1..8).each do |n|
            events << create_event_from_string_date(
              "phase#{n}", attributes.dig('claimPhaseDates', 'previousPhases', "phase#{n}CompleteDate")
            )
          end

          # Add tracked items
          events += create_events_for_tracked_items(attributes)

          # Add documents not associated with a tracked item
          events += create_events_for_documents(attributes)

          # sort to put events with uploaded == false on top and then by date
          events.compact.sort_by do |event|
            upload_priority = if event[:uploaded] || event[:uploaded].nil?
                                0 # Lower priority for uploaded == true or value nil
                              else
                                1 # Higher priority for uploaded == false
                              end
            event_date = event[:date] || DEFAULT_DATE

            [upload_priority, event_date]
          end.reverse
        end

        def create_event_from_string_date(type, date)
          return nil unless date

          ClaimEventTimeline.new(
            type:,
            date: Date.strptime(date, '%Y-%m-%d')
          )
        end

        def create_events_for_tracked_items(attributes)
          attributes['trackedItems'].map do |tracked_item|
            tracked_item_documents = attributes['supportingDocuments']&.select do |document|
              document['trackedItemId'] == tracked_item['id']
            end
            create_tracked_item_event(tracked_item, tracked_item_documents)
          end
        end

        def create_events_for_documents(attributes)
          untracked_documents = attributes['supportingDocuments'].select { |document| document['trackedItemId'].nil? }
          untracked_documents.map do |document|
            ClaimEventTimeline.new(
              type: :other_documents_list,
              tracked_item_id: document['trackedItemId'],
              upload_date: document['uploadDate'],
              file_type: document['documentTypeLabel'],
              filename: document['originalFileName'],
              document_id: document['documentId']
            )
          end
        end

        def create_tracked_item_event(tracked_item, tracked_item_documents)
          documents = create_documents(tracked_item_documents)

          event = {
            type: LH_STATUS_TO_EVSS_TYPE[tracked_item['status'].to_sym],
            tracked_item_id: tracked_item['id'],
            description: tracked_item['description'],
            display_name: tracked_item['displayName'],
            overdue: tracked_item['overdue'],
            status: LH_STATUS_TO_EVSS_STATUS[tracked_item['status'].to_sym],
            uploaded: tracked_item_documents&.any? || false,
            uploads_allowed: tracked_item['uploadsAllowed'],
            opened_date: tracked_item['requestedDate'],
            requested_date: tracked_item['requestedDate'],
            received_date: tracked_item['receivedDate'],
            closed_date: tracked_item['closedDate'],
            suspense_date: tracked_item['suspenseDate'],
            documents:,
            upload_date: latest_upload_date(documents)
          }

          event[:date] = Date.strptime(event.slice(*EVENT_DATE_FIELDS).values.compact.first, '%Y-%m-%d')
          ClaimEventTimeline.new(event)
        end

        def create_documents(documents)
          documents.map do |document|
            document_hash = {
              tracked_item_id: document['trackedItemId'],
              file_type: document['documentTypeLabel'],
              # no document type field available
              document_type: nil,
              filename: document['originalFileName'],
              upload_date: document['uploadDate'],
              document_id: document['documentId']
            }
            ClaimDocument.new(document_hash)
          end
        end

        def latest_upload_date(documents)
          documents.pluck(:upload_date).max
        end

        def collect_download_eligible_documents(events_timeline)
          document_data = []

          events_timeline.each do |event|
            has_tracked_documents = event.documents.present?
            has_untracked_document = event.type == :other_documents_list

            if has_tracked_documents
              valid_docs = event.documents.select { |doc| valid_doc?(doc) }

              valid_docs.each do |doc|
                document_data << build_doc_obj(doc)
              end
            elsif has_untracked_document && valid_doc?(event)
              document_data << build_doc_obj(event)
            end
          end
          document_data
        end

        def valid_doc?(obj)
          obj.filename.present? && obj.document_id.present?
        end

        def build_doc_obj(obj)
          {
            document_id: obj.document_id,
            filename: obj.filename
          }
        end
      end
    end
  end
end
