# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module ClaimSerializer
        def self.to_json_api(dto)
          {
            'id' => dto.id,
            'type' => dto.type,
            'attributes' => serialize_claim_attributes(dto)
          }.with_indifferent_access
        end

        def self.serialize_claim_attributes(dto)
          attributes = {
            'baseEndProductCode' => dto.base_end_product_code,
            'claimDate' => dto.claim_date,
            'claimType' => dto.claim_type,
            'claimTypeCode' => dto.claim_type_code,
            'displayTitle' => dto.display_title,
            'claimTypeBase' => dto.claim_type_base,
            'closeDate' => dto.close_date,
            'decisionLetterSent' => dto.decision_letter_sent,
            'developmentLetterSent' => dto.development_letter_sent,
            'documentsNeeded' => dto.documents_needed,
            'endProductCode' => dto.end_product_code,
            'evidenceWaiverSubmitted5103' => dto.evidence_waiver_submitted5103,
            'lighthouseId' => dto.lighthouse_id,
            'status' => dto.status
          }

          attributes['claimPhaseDates'] = serialize_phase_dates(dto.claim_phase_dates) if dto.claim_phase_dates
          if dto.supporting_documents
            attributes['supportingDocuments'] =
              serialize_supporting_documents(dto.supporting_documents)
          end
          attributes['evidenceSubmissions'] = dto.evidence_submissions if dto.evidence_submissions
          attributes['contentions'] = serialize_contentions(dto.contentions) if dto.contentions
          attributes['events'] = serialize_events(dto.events) if dto.events
          attributes['issues'] = serialize_issues(dto.issues) if dto.issues
          attributes['evidence'] = serialize_evidence(dto.evidence) if dto.evidence
          attributes['trackedItems'] = serialize_tracked_items(dto.tracked_items) if dto.tracked_items

          attributes
        end

        def self.serialize_phase_dates(phase_dates)
          {
            'phaseChangeDate' => phase_dates.phase_change_date,
            'currentPhaseBack' => phase_dates.current_phase_back,
            'phaseType' => phase_dates.phase_type,
            'latestPhaseType' => phase_dates.latest_phase_type,
            'previousPhases' => phase_dates.previous_phases
          }.compact
        end

        def self.serialize_tracked_items(tracked_items)
          tracked_items.map do |item|
            {
              'id' => item.id,
              'displayName' => item.display_name,
              'status' => item.status,
              'suspenseDate' => item.suspense_date,
              'type' => item.type
            }.compact
          end
        end

        def self.serialize_supporting_documents(documents)
          documents.map do |doc|
            {
              'documentId' => doc.document_id,
              'documentTypeLabel' => doc.document_type_label,
              'originalFileName' => doc.original_file_name,
              'trackedItemId' => doc.tracked_item_id,
              'uploadDate' => doc.upload_date
            }.compact
          end
        end

        def self.serialize_contentions(contentions)
          contentions.map do |contention|
            {
              'name' => contention.name
            }.compact
          end
        end

        def self.serialize_events(events)
          events.map do |event|
            {
              'date' => event.date,
              'type' => event.type
            }.compact
          end
        end

        def self.serialize_issues(issues)
          issues.map do |issue|
            {
              'active' => issue.active,
              'description' => issue.description,
              'diagnosticCode' => issue.diagnostic_code,
              'lastAction' => issue.last_action,
              'date' => issue.date
            }.compact
          end
        end

        def self.serialize_evidence(evidence_list)
          evidence_list.map do |ev|
            {
              'date' => ev.date,
              'description' => ev.description,
              'type' => ev.type
            }.compact
          end
        end
      end
    end
  end
end
