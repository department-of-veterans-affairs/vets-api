# frozen_string_literal: true

require 'benefits_claims/responses/claim_response'
require 'benefits_claims/title_generator'

module BenefitsClaims
  module Providers
    module IvcChampva
      module ClaimBuilder
        FORM_TYPE_MAP = {
          'vha1010d' => 'CHAMPVA application',
          'vha_10_10d' => 'CHAMPVA application',
          'vha_10_10d_2027' => 'CHAMPVA application',
          '10-10d' => 'CHAMPVA application',
          '10-7959c' => 'Other Health Insurance',
          '10-7959f-1' => 'Foreign Medical Program registration',
          '10-7959f-2' => 'Foreign Medical Program claim',
          '10-7959a' => 'CHAMPVA claim'
        }.freeze

        PROCESSED_STATUSES = ['Processed', 'Manually Processed'].freeze

        def self.build_claim_response(records)
          records = Array(records)
          representative = pick_representative(records)
          claim_type = claim_type_for(representative&.form_number)
          titles = BenefitsClaims::TitleGenerator.generate_titles(claim_type, nil)

          BenefitsClaims::Responses::ClaimResponse.new(
            id: representative&.form_uuid,
            claim_date: format_date(records.min_by(&:created_at)&.created_at),
            close_date: close_date_for(representative),
            claim_type: claim_type,
            display_title: titles[:display_title],
            claim_type_base: titles[:claim_type_base],
            status: status_for(records),
            supporting_documents: build_supporting_documents(records)
          )
        end

        def self.pick_representative(records)
          records.max_by(&:updated_at)
        end

        def self.claim_type_for(form_number)
          normalized = normalize_form_number(form_number)
          FORM_TYPE_MAP[normalized] || form_number
        end

        def self.normalize_form_number(value)
          value.to_s.strip.downcase
        end

        def self.status_for(records)
          latest_with_status = records.select { |record| record.pega_status.present? }
                                      .max_by(&:updated_at)

          return latest_with_status.pega_status if latest_with_status

          'Submission failed'
        end

        def self.close_date_for(record)
          return nil unless record&.pega_status && PROCESSED_STATUSES.include?(record.pega_status)

          format_date(record.updated_at)
        end

        def self.build_supporting_documents(records)
          records.map do |record|
            BenefitsClaims::Responses::SupportingDocument.new(
              document_id: record.id.to_s,
              document_type_label: nil,
              original_file_name: record.file_name,
              tracked_item_id: nil,
              upload_date: format_datetime(record.created_at)
            )
          end
        end

        def self.format_date(value)
          value&.to_date&.iso8601
        end

        def self.format_datetime(value)
          value&.iso8601
        end
      end
    end
  end
end
