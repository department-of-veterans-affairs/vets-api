# frozen_string_literal: true

require 'hca/enrollment_eligibility/constants'

# rubocop:disable Metrics/ModuleLength
module HCA
  module EnrollmentEligibility
    module StatusMatcher
      module_function

      # Defines the collection of eligible HCA enrollment statuses.
      #
      # To add a new status, it **must also be added** to the
      # /app/models/notification#status enum values hash.
      #
      ELIGIBLE_STATUS_CATEGORIES = [
        HCA::EnrollmentEligibility::Constants::ACTIVEDUTY,
        HCA::EnrollmentEligibility::Constants::CANCELED_DECLINED,
        HCA::EnrollmentEligibility::Constants::CLOSED,
        HCA::EnrollmentEligibility::Constants::DECEASED,
        HCA::EnrollmentEligibility::Constants::ENROLLED,
        HCA::EnrollmentEligibility::Constants::INELIG_CHAMPVA,
        HCA::EnrollmentEligibility::Constants::INELIG_CHARACTER_OF_DISCHARGE,
        HCA::EnrollmentEligibility::Constants::INELIG_CITIZENS,
        HCA::EnrollmentEligibility::Constants::INELIG_FILIPINOSCOUTS,
        HCA::EnrollmentEligibility::Constants::INELIG_FUGITIVEFELON,
        HCA::EnrollmentEligibility::Constants::INELIG_GUARD_RESERVE,
        HCA::EnrollmentEligibility::Constants::INELIG_MEDICARE,
        HCA::EnrollmentEligibility::Constants::INELIG_NOT_ENOUGH_TIME,
        HCA::EnrollmentEligibility::Constants::INELIG_NOT_VERIFIED,
        HCA::EnrollmentEligibility::Constants::INELIG_OTHER,
        HCA::EnrollmentEligibility::Constants::INELIG_OVER65,
        HCA::EnrollmentEligibility::Constants::INELIG_REFUSEDCOPAY,
        HCA::EnrollmentEligibility::Constants::INELIG_TRAINING_ONLY,
        HCA::EnrollmentEligibility::Constants::LOGIN_REQUIRED,
        HCA::EnrollmentEligibility::Constants::NONE_OF_THE_ABOVE,
        HCA::EnrollmentEligibility::Constants::PENDING_MT,
        HCA::EnrollmentEligibility::Constants::PENDING_OTHER,
        HCA::EnrollmentEligibility::Constants::PENDING_PURPLEHEART,
        HCA::EnrollmentEligibility::Constants::PENDING_UNVERIFIED,
        HCA::EnrollmentEligibility::Constants::REJECTED_INC_WRONGENTRY,
        HCA::EnrollmentEligibility::Constants::REJECTED_RIGHTENTRY,
        HCA::EnrollmentEligibility::Constants::REJECTED_SC_WRONGENTRY,
        HCA::EnrollmentEligibility::Constants::NON_MILITARY
      ].freeze

      CATCHALL_CATEGORIES = [
        {
          enrollment_status: 'rejected',
          category: HCA::EnrollmentEligibility::Constants::REJECTED_RIGHTENTRY
        },
        {
          enrollment_status: 'not eligible',
          category: HCA::EnrollmentEligibility::Constants::INELIG_OTHER
        }
      ].freeze

      CATEGORIES = [
        {
          enrollment_status: 'verified',
          category: HCA::EnrollmentEligibility::Constants::ENROLLED
        },
        {
          enrollment_status: ['not eligible', 'not eligible; ineligible date'],
          text_matches: [
            {
              category: HCA::EnrollmentEligibility::Constants::INELIG_NOT_ENOUGH_TIME,
              strings: ['24 months', 'less than', '24 mos', '24months', 'two years']
            },
            {
              category: HCA::EnrollmentEligibility::Constants::INELIG_TRAINING_ONLY,
              strings: ['training only', 'trng only'],
              acronyms: %w[ADT ACDUTRA ADUTRA]
            },
            {
              category: HCA::EnrollmentEligibility::Constants::INELIG_CHARACTER_OF_DISCHARGE,
              strings: [
                'other than honorable', 'dishonorable',
                'bad conduct', 'dis for va pur'
              ],
              acronyms: %w[OTH DVA]
            },
            {
              category: HCA::EnrollmentEligibility::Constants::INELIG_NOT_VERIFIED,
              strings: ['no proof', 'no record', 'non-vet', 'non vet', 'unable to verify', 'not a veteran', '214']
            },
            {
              category: HCA::EnrollmentEligibility::Constants::INELIG_GUARD_RESERVE,
              strings: %w[guard reserve reservist]
            },
            {
              category: HCA::EnrollmentEligibility::Constants::INELIG_CHAMPVA,
              strings: ['champva']
            },
            {
              category: HCA::EnrollmentEligibility::Constants::INELIG_FUGITIVEFELON,
              strings: ['felon']
            },
            {
              category: HCA::EnrollmentEligibility::Constants::INELIG_MEDICARE,
              strings: ['medicare']
            },
            {
              category: HCA::EnrollmentEligibility::Constants::INELIG_OVER65,
              strings: ['over 65']
            },
            {
              category: HCA::EnrollmentEligibility::Constants::INELIG_CITIZENS,
              strings: ['citizen']
            },
            {
              category: HCA::EnrollmentEligibility::Constants::INELIG_FILIPINOSCOUTS,
              strings: ['filipino']
            },
            {
              category: HCA::EnrollmentEligibility::Constants::REJECTED_SC_WRONGENTRY,
              strings: ['disability']
            },
            {
              category: HCA::EnrollmentEligibility::Constants::REJECTED_INC_WRONGENTRY,
              strings: ['income']
            }
          ]
        },
        {
          enrollment_status: 'not applicable',
          category: HCA::EnrollmentEligibility::Constants::ACTIVEDUTY
        },
        {
          enrollment_status: 'deceased',
          category: HCA::EnrollmentEligibility::Constants::DECEASED
        },
        {
          enrollment_status: 'closed application',
          category: HCA::EnrollmentEligibility::Constants::CLOSED
        },
        {
          enrollment_status: 'not eligible; refused to pay copay',
          category: HCA::EnrollmentEligibility::Constants::INELIG_REFUSEDCOPAY
        },
        {
          enrollment_status: 'pending; means test required',
          category: HCA::EnrollmentEligibility::Constants::PENDING_MT
        },
        {
          enrollment_status: 'pending; eligibility status is unverified',
          category: HCA::EnrollmentEligibility::Constants::PENDING_UNVERIFIED
        },
        {
          enrollment_status: 'pending; other',
          category: HCA::EnrollmentEligibility::Constants::PENDING_OTHER
        },
        {
          enrollment_status: 'pending; purple heart unconfirmed',
          category: HCA::EnrollmentEligibility::Constants::PENDING_PURPLEHEART
        },
        {
          enrollment_status: 'cancelled/declined',
          category: HCA::EnrollmentEligibility::Constants::CANCELED_DECLINED
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

      def parse_catchall_categories(enrollment_status)
        CATCHALL_CATEGORIES.each do |category_data|
          return category_data[:category] if enrollment_status.include?(category_data[:enrollment_status])
        end

        nil
      end

      def parse(enrollment_status, ineligibility_reason = '')
        return HCA::EnrollmentEligibility::Constants::NONE_OF_THE_ABOVE if enrollment_status.blank?

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

        parse_catchall_categories(enrollment_status).tap { |c| return c if c.present? }

        HCA::EnrollmentEligibility::Constants::NONE_OF_THE_ABOVE
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
