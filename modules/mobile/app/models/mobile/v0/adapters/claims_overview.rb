# frozen_string_literal: true

require 'benefits_claims/title_generator'

module Mobile
  module V0
    module Adapters
      class ClaimsOverview
        FEATURE_USE_TITLE_GENERATOR_MOBILE = 'cst_use_claim_title_generator_mobile'

        APPEALS_TYPES = {
          legacy: 'legacyAppeal',
          supplemental_claim: 'supplementalClaim',
          higher_level_review: 'higherLevelReview',
          appeal: 'appeal'
        }.freeze

        APPEALS_DISPLAY_TYPES = {
          legacy: 'appeal',
          supplemental_claim: 'supplemental claim',
          higher_level_review: 'higher-level review',
          appeal: 'appeal'
        }.freeze

        PROGRAM_AREA_MAP = {
          compensation: 'disability compensation',
          pension: 'pension',
          insurance: 'insurance',
          loan_guaranty: 'loan guaranty',
          education: 'education',
          vre: 'vocational rehabilitation and employment',
          medical: 'health care',
          burial: 'burial benefits',
          fiduciary: 'fiduciary'
        }.freeze

        def parse(list)
          list
            .map { |entry| entry['type'] == 'claim' ? parse_claim(entry) : parse_appeal(entry) }
            .sort_by { |entry| [entry[:updated_at] ? 1 : 0, entry[:updated_at]] }.reverse!
        end

        private

        def parse_claim(entry)
          attributes = entry['attributes']
          claim_type = attributes['claimType']
          claim_type_code = attributes['claimTypeCode']

          titles = BenefitsClaims::TitleGenerator.generate_titles(claim_type, claim_type_code)

          build_claim(entry['id'], attributes, claim_type_code, titles, entry['provider'])
        end

        def build_claim(id, attributes, claim_type_code, titles, provider = nil)
          use_generated_titles = Flipper.enabled?(FEATURE_USE_TITLE_GENERATOR_MOBILE)
          Mobile::V0::ClaimOverview.new(
            {
              id:,
              type: 'claim',
              subtype: attributes['claimType'],
              completed: attributes['status'] == 'COMPLETE',
              date_filed: date(attributes['claimDate']),
              updated_at: date(attributes['claimPhaseDates']['phaseChangeDate']),
              display_title: use_generated_titles ? titles[:display_title] : attributes['claimType'],
              decision_letter_sent: attributes['decisionLetterSent'],
              phase: Mobile::ClaimsHelper.phase_to_number(attributes['claimPhaseDates']['phaseType']),
              documents_needed: documents_needed(attributes),
              development_letter_sent: attributes['developmentLetterSent'],
              claim_type_code:,
              claim_type_base: titles[:claim_type_base],
              provider:
            }
          )
        end

        def parse_appeal(entry)
          subtype = entry['type']
          filed_index = subtype == 'legacyAppeal' ? 1 : 0
          Mobile::V0::ClaimOverview.new(
            {
              id: entry['id'],
              type: 'appeal',
              subtype:,
              completed: !entry['attributes']['active'],
              date_filed: entry['attributes']['events'][filed_index]['date'],
              updated_at: entry['attributes']['events'].last['date'],
              display_title: get_appeals_display_title(subtype, entry['attributes']['programArea']),
              decision_letter_sent: false
            }
          )
        end

        def get_appeals_display_title(type, program_area)
          appeal_key = APPEALS_TYPES.key(type)
          appeal_display_text = APPEALS_DISPLAY_TYPES[appeal_key]
          program_area_sym = program_area.blank? ? :other : program_area.to_sym
          program_area_text = PROGRAM_AREA_MAP[program_area_sym] ? PROGRAM_AREA_MAP[program_area_sym].to_s : ''
          if type == APPEALS_TYPES[:appeal] || type == APPEALS_TYPES[:legacy]
            "#{program_area_text} #{appeal_display_text}".lstrip
          else
            "#{appeal_display_text} for #{program_area_text}"
          end
        end

        def documents_needed(attributes)
          attributes['evidenceWaiverSubmitted5103'] ? false : attributes['documentsNeeded']
        end

        def date(attribute)
          return nil unless attribute

          Date.strptime(attribute, '%Y-%m-%d').iso8601
        end
      end
    end
  end
end
