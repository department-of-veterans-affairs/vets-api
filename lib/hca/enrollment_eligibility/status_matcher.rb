# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module HCA
  module EnrollmentEligibility
    module StatusMatcher
      module_function
      include ParsedStatuses

      CATEGORIES = [
        {
          enrollment_status: 'verified',
          category: ENROLLED
        },
        {
          enrollment_status: ['not eligible', 'not eligible; ineligible date'],
          text_matches: [
            {
              category: INELIG_NOT_ENOUGH_TIME,
              strings: ['24 months', 'less than', '24 mos', '24months', 'two years']
            },
            {
              category: INELIG_TRAINING_ONLY,
              strings: ['training only', 'trng only'],
              acronyms: %w[ADT ACDUTRA ADUTRA]
            },
            {
              category: INELIG_CHARACTER_OF_DISCHARGE,
              strings: [
                'other than honorable', 'dishonorable',
                'bad conduct', 'dis for va pur'
              ],
              acronyms: %w[OTH DVA]
            },
            {
              category: INELIG_NOT_VERIFIED,
              strings: ['no proof', 'no record', 'non-vet', 'non vet', 'unable to verify', 'not a veteran', '214']
            },
            {
              category: INELIG_GUARD_RESERVE,
              strings: %w[guard reserve reservist]
            },
            {
              category: INELIG_CHAMPVA,
              strings: ['champva']
            },
            {
              category: INELIG_FUGITIVEFELON,
              strings: ['felon']
            },
            {
              category: INELIG_MEDICARE,
              strings: ['medicare']
            },
            {
              category: INELIG_OVER65,
              strings: ['over 65']
            },
            {
              category: INELIG_CITIZENS,
              strings: ['citizen']
            },
            {
              category: INELIG_FILIPINOSCOUTS,
              strings: ['filipino']
            },
            {
              category: REJECTED_SC_WRONGENTRY,
              strings: ['disability']
            },
            {
              category: REJECTED_INC_WRONGENTRY,
              strings: ['income']
            }
          ]
        },
        {
          enrollment_status: 'not applicable',
          category: ACTIVEDUTY
        },
        {
          enrollment_status: 'deceased',
          category: DECEASED
        },
        {
          enrollment_status: 'closed application',
          category: CLOSED
        },
        {
          enrollment_status: 'not eligible; refused to pay copay',
          category: INELIG_REFUSEDCOPAY
        },
        {
          enrollment_status: 'pending; means test required',
          category: PENDING_MT
        },
        {
          enrollment_status: 'pending; eligibility status is unverified',
          category: PENDING_UNVERIFIED
        },
        {
          enrollment_status: 'pending; other',
          category: PENDING_OTHER
        },
        {
          enrollment_status: 'pending; purple heart unconfirmed',
          category: PENDING_PURPLEHEART
        },
        {
          enrollment_status: 'cancelled/declined',
          category: CANCELED_DECLINED
        }
      ].freeze

      def process_text_match(text_matches, ineligibility_reason)
        text_matches.each do |text_match_data|
          category = text_match_data[:category]

          text_match_data[:strings].each do |string|
            return category if ineligibility_reason.downcase.include?(string)
          end

          text_match_data[:acronyms].tap do |acronyms|
            next if acronyms.blank?

            acronyms.each do |acronym|
              return category if ineligibility_reason.include?(acronym)
            end
          end
        end

        nil
      end

      def category_matcher(statuses, enroll_status)
        return statuses.include?(enroll_status) if statuses.is_a?(Array)
        enroll_status == statuses
      end

      def parse(enrollment_status, ineligibility_reason = '')
        return NONE if enrollment_status.blank?
        enrollment_status = enrollment_status.downcase.strip

        CATEGORIES.find { |c| category_matcher(c[:enrollment_status], enrollment_status) }.tap do |category_data|
          next unless category_data
          if category_data[:text_matches]
            process_text_match(category_data[:text_matches], ineligibility_reason).tap do |category|
              return category if category.present?
            end
          else
            return category_data[:category]
          end
        end

        return REJECTED_RIGHTENTRY if enrollment_status.include?('rejected')

        NONE
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
