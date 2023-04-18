# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class ClaimsOverview
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
            .map { |entry| entry['list_data'] ? parse_claim(entry) : parse_appeal(entry) }
            .sort_by(&:updated_at).reverse!
        end

        private

        def parse_claim(entry)
          Mobile::V0::ClaimOverview.new(
            {
              id: entry['evss_id'].to_s,
              type: 'claim',
              subtype: entry['list_data']['status_type'],
              completed: entry['list_data']['status'] == 'COMPLETE', # TODO: ADJ what's the business logic  here?
              date_filed: Date.strptime(entry['list_data']['date'], '%m/%d/%Y').iso8601,
              updated_at: Date.strptime(
                entry['list_data']['claim_phase_dates']['phase_change_date'], '%m/%d/%Y'
              ).iso8601,
              display_title: entry['list_data']['status_type'],
              decision_letter_sent: entry['list_data']['decision_notification_sent'] == 'Yes'
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
          program_area_text = PROGRAM_AREA_MAP[program_area_sym] ? (PROGRAM_AREA_MAP[program_area_sym]).to_s : ''
          if type == APPEALS_TYPES[:appeal] || type == APPEALS_TYPES[:legacy]
            "#{program_area_text} #{appeal_display_text}".lstrip
          else
            "#{appeal_display_text} for #{program_area_text}"
          end
        end
      end
    end
  end
end
