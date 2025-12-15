# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module ClaimBuilder
        def self.build_claim_response(claim_data)
          BenefitsClaims::Responses::ClaimResponse.new(
            id: claim_data['id'],
            type: claim_data['type'],
            base_end_product_code: claim_data.dig('attributes', 'baseEndProductCode'),
            claim_date: claim_data.dig('attributes', 'claimDate'),
            claim_phase_dates: build_claim_phase_dates(claim_data.dig('attributes', 'claimPhaseDates')),
            claim_type: claim_data.dig('attributes', 'claimType'),
            claim_type_code: claim_data.dig('attributes', 'claimTypeCode'),
            display_title: claim_data.dig('attributes', 'displayTitle'),
            claim_type_base: claim_data.dig('attributes', 'claimTypeBase'),
            close_date: claim_data.dig('attributes', 'closeDate'),
            decision_letter_sent: claim_data.dig('attributes', 'decisionLetterSent'),
            development_letter_sent: claim_data.dig('attributes', 'developmentLetterSent'),
            documents_needed: claim_data.dig('attributes', 'documentsNeeded'),
            end_product_code: claim_data.dig('attributes', 'endProductCode'),
            evidence_waiver_submitted5103: claim_data.dig('attributes', 'evidenceWaiverSubmitted5103'),
            lighthouse_id: claim_data.dig('attributes', 'lighthouseId'),
            status: claim_data.dig('attributes', 'status'),
            supporting_documents: build_supporting_documents(claim_data.dig('attributes', 'supportingDocuments')),
            evidence_submissions: claim_data.dig('attributes', 'evidenceSubmissions') || [],
            contentions: build_contentions(claim_data.dig('attributes', 'contentions')),
            events: build_events(claim_data.dig('attributes', 'events')),
            issues: build_issues(claim_data.dig('attributes', 'issues')),
            evidence: build_evidence(claim_data.dig('attributes', 'evidence')),
            tracked_items: build_tracked_items(claim_data.dig('attributes', 'trackedItems'))
          )
        end

        def self.build_claim_phase_dates(phase_dates_data)
          return nil if phase_dates_data.nil?

          BenefitsClaims::Responses::ClaimPhaseDates.new(
            phase_change_date: phase_dates_data['phaseChangeDate'],
            current_phase_back: phase_dates_data['currentPhaseBack'],
            phase_type: phase_dates_data['phaseType'],
            latest_phase_type: phase_dates_data['latestPhaseType'],
            previous_phases: phase_dates_data['previousPhases']
          )
        end

        def self.build_tracked_items(tracked_items_data)
          return nil if tracked_items_data.nil?
          return [] if tracked_items_data.empty?

          tracked_items_data.map do |item_data|
            BenefitsClaims::Responses::TrackedItem.new(
              id: item_data['id'],
              display_name: item_data['displayName'],
              status: item_data['status'],
              suspense_date: item_data['suspenseDate'],
              type: item_data['type']
            )
          end
        end

        def self.build_supporting_documents(documents_data)
          return nil if documents_data.nil?
          return [] if documents_data.empty?

          documents_data.map do |doc_data|
            BenefitsClaims::Responses::SupportingDocument.new(
              document_id: doc_data['documentId'],
              document_type_label: doc_data['documentTypeLabel'],
              original_file_name: doc_data['originalFileName'],
              tracked_item_id: doc_data['trackedItemId'],
              upload_date: doc_data['uploadDate']
            )
          end
        end

        def self.build_contentions(contentions_data)
          return nil if contentions_data.nil?
          return [] if contentions_data.empty?

          contentions_data.map do |contention_data|
            BenefitsClaims::Responses::Contention.new(
              name: contention_data['name']
            )
          end
        end

        def self.build_events(events_data)
          return nil if events_data.nil?
          return [] if events_data.empty?

          events_data.map do |event_data|
            BenefitsClaims::Responses::Event.new(
              date: event_data['date'],
              type: event_data['type']
            )
          end
        end

        def self.build_issues(issues_data)
          return nil if issues_data.nil?
          return [] if issues_data.empty?

          issues_data.map do |issue_data|
            BenefitsClaims::Responses::Issue.new(
              active: issue_data['active'],
              description: issue_data['description'],
              diagnostic_code: issue_data['diagnosticCode'],
              last_action: issue_data['lastAction'],
              date: issue_data['date']
            )
          end
        end

        def self.build_evidence(evidence_data)
          return nil if evidence_data.nil?
          return [] if evidence_data.empty?

          evidence_data.map do |ev_data|
            BenefitsClaims::Responses::Evidence.new(
              date: ev_data['date'],
              description: ev_data['description'],
              type: ev_data['type']
            )
          end
        end
      end
    end
  end
end
