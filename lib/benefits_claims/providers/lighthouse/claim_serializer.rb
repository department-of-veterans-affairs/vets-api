# frozen_string_literal: true

require_relative 'serializers/phase_dates_serializer'
require_relative 'serializers/tracked_items_serializer'
require_relative 'serializers/supporting_documents_serializer'
require_relative 'serializers/contentions_serializer'
require_relative 'serializers/events_serializer'
require_relative 'serializers/issues_serializer'
require_relative 'serializers/evidence_serializer'

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
            'provider' => dto.provider,
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

          add_optional_attributes(attributes, dto)
          attributes
        end

        def self.add_optional_attributes(attributes, dto)
          if dto.claim_phase_dates
            attributes['claimPhaseDates'] =
              Serializers::PhaseDatesSerializer.serialize(dto.claim_phase_dates)
          end

          # Always include array attributes (even if empty) for consistent API responses
          # The DTO defaults ensure these are always arrays, never nil
          attributes['supportingDocuments'] =
            Serializers::SupportingDocumentsSerializer.serialize(dto.supporting_documents)

          # evidenceSubmissions is special - it's added by controller based on feature flags,
          # not from Lighthouse API. Only include if present.
          attributes['evidenceSubmissions'] = dto.evidence_submissions if dto.evidence_submissions&.any?

          attributes['contentions'] = Serializers::ContentionsSerializer.serialize(dto.contentions)
          attributes['events'] = Serializers::EventsSerializer.serialize(dto.events)
          attributes['issues'] = Serializers::IssuesSerializer.serialize(dto.issues)
          attributes['evidence'] = Serializers::EvidenceSerializer.serialize(dto.evidence)
          attributes['trackedItems'] = Serializers::TrackedItemsSerializer.serialize(dto.tracked_items)
        end
      end
    end
  end
end
