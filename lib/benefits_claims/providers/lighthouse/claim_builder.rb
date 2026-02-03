# frozen_string_literal: true

require_relative 'builders/phase_dates_builder'
require_relative 'builders/tracked_items_builder'
require_relative 'builders/supporting_documents_builder'
require_relative 'builders/contentions_builder'
require_relative 'builders/events_builder'
require_relative 'builders/issues_builder'
require_relative 'builders/evidence_builder'

module BenefitsClaims
  module Providers
    module Lighthouse
      module ClaimBuilder
        def self.build_claim_response(claim_data)
          attrs = claim_data['attributes']
          BenefitsClaims::Responses::ClaimResponse.new(build_claim_params(claim_data, attrs))
        end

        def self.build_claim_params(claim_data, attrs)
          build_core_attributes(claim_data, attrs).merge(build_nested_attributes(attrs))
        end

        def self.build_core_attributes(claim_data, attrs)
          {
            id: claim_data['id'],
            type: claim_data['type'],
            provider: claim_data['provider'],
            base_end_product_code: attrs['baseEndProductCode'],
            claim_date: attrs['claimDate'],
            claim_type: attrs['claimType'],
            claim_type_code: attrs['claimTypeCode'],
            display_title: attrs['displayTitle'],
            claim_type_base: attrs['claimTypeBase'],
            close_date: attrs['closeDate'],
            decision_letter_sent: attrs['decisionLetterSent'],
            development_letter_sent: attrs['developmentLetterSent'],
            documents_needed: attrs['documentsNeeded'],
            end_product_code: attrs['endProductCode'],
            evidence_waiver_submitted5103: attrs['evidenceWaiverSubmitted5103'],
            lighthouse_id: attrs['lighthouseId'],
            status: attrs['status']
          }
        end

        def self.build_nested_attributes(attrs)
          {
            claim_phase_dates: Builders::PhaseDatesBuilder.build(attrs['claimPhaseDates']),
            supporting_documents: Builders::SupportingDocumentsBuilder.build(attrs['supportingDocuments']),
            evidence_submissions: attrs['evidenceSubmissions'] || [],
            contentions: Builders::ContentionsBuilder.build(attrs['contentions']),
            events: Builders::EventsBuilder.build(attrs['events']),
            issues: Builders::IssuesBuilder.build(attrs['issues']),
            evidence: Builders::EvidenceBuilder.build(attrs['evidence']),
            tracked_items: Builders::TrackedItemsBuilder.build(attrs['trackedItems'])
          }
        end
      end
    end
  end
end
