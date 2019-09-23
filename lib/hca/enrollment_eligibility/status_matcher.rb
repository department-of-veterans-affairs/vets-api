# frozen_string_literal: true

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
        Notification::ACTIVEDUTY,
        Notification::CANCELED_DECLINED,
        Notification::CLOSED,
        Notification::DECEASED,
        Notification::ENROLLED,
        Notification::INELIG_CHAMPVA,
        Notification::INELIG_CHARACTER_OF_DISCHARGE,
        Notification::INELIG_CITIZENS,
        Notification::INELIG_FILIPINOSCOUTS,
        Notification::INELIG_FUGITIVEFELON,
        Notification::INELIG_GUARD_RESERVE,
        Notification::INELIG_MEDICARE,
        Notification::INELIG_NOT_ENOUGH_TIME,
        Notification::INELIG_NOT_VERIFIED,
        Notification::INELIG_OTHER,
        Notification::INELIG_OVER65,
        Notification::INELIG_REFUSEDCOPAY,
        Notification::INELIG_TRAINING_ONLY,
        Notification::LOGIN_REQUIRED,
        Notification::NONE_OF_THE_ABOVE,
        Notification::PENDING_MT,
        Notification::PENDING_OTHER,
        Notification::PENDING_PURPLEHEART,
        Notification::PENDING_UNVERIFIED,
        Notification::REJECTED_INC_WRONGENTRY,
        Notification::REJECTED_RIGHTENTRY,
        Notification::REJECTED_SC_WRONGENTRY,
        Notification::NON_MILITARY
      ].freeze

      CATCHALL_CATEGORIES = [
        {
          enrollment_status: 'rejected',
          category: Notification::REJECTED_RIGHTENTRY
        },
        {
          enrollment_status: 'not eligible',
          category: Notification::INELIG_OTHER
        }
      ].freeze

      CATEGORIES = [
        {
          enrollment_status: 'verified',
          category: Notification::ENROLLED
        },
        {
          enrollment_status: ['not eligible', 'not eligible; ineligible date'],
          text_matches: [
            {
              category: Notification::INELIG_NOT_ENOUGH_TIME,
              strings: ['24 months', 'less than', '24 mos', '24months', 'two years']
            },
            {
              category: Notification::INELIG_TRAINING_ONLY,
              strings: ['training only', 'trng only'],
              acronyms: %w[ADT ACDUTRA ADUTRA]
            },
            {
              category: Notification::INELIG_CHARACTER_OF_DISCHARGE,
              strings: [
                'other than honorable', 'dishonorable',
                'bad conduct', 'dis for va pur'
              ],
              acronyms: %w[OTH DVA]
            },
            {
              category: Notification::INELIG_NOT_VERIFIED,
              strings: ['no proof', 'no record', 'non-vet', 'non vet', 'unable to verify', 'not a veteran', '214']
            },
            {
              category: Notification::INELIG_GUARD_RESERVE,
              strings: %w[guard reserve reservist]
            },
            {
              category: Notification::INELIG_CHAMPVA,
              strings: ['champva']
            },
            {
              category: Notification::INELIG_FUGITIVEFELON,
              strings: ['felon']
            },
            {
              category: Notification::INELIG_MEDICARE,
              strings: ['medicare']
            },
            {
              category: Notification::INELIG_OVER65,
              strings: ['over 65']
            },
            {
              category: Notification::INELIG_CITIZENS,
              strings: ['citizen']
            },
            {
              category: Notification::INELIG_FILIPINOSCOUTS,
              strings: ['filipino']
            },
            {
              category: Notification::REJECTED_SC_WRONGENTRY,
              strings: ['disability']
            },
            {
              category: Notification::REJECTED_INC_WRONGENTRY,
              strings: ['income']
            }
          ]
        },
        {
          enrollment_status: 'not applicable',
          category: Notification::ACTIVEDUTY
        },
        {
          enrollment_status: 'deceased',
          category: Notification::DECEASED
        },
        {
          enrollment_status: 'closed application',
          category: Notification::CLOSED
        },
        {
          enrollment_status: 'not eligible; refused to pay copay',
          category: Notification::INELIG_REFUSEDCOPAY
        },
        {
          enrollment_status: 'pending; means test required',
          category: Notification::PENDING_MT
        },
        {
          enrollment_status: 'pending; eligibility status is unverified',
          category: Notification::PENDING_UNVERIFIED
        },
        {
          enrollment_status: 'pending; other',
          category: Notification::PENDING_OTHER
        },
        {
          enrollment_status: 'pending; purple heart unconfirmed',
          category: Notification::PENDING_PURPLEHEART
        },
        {
          enrollment_status: 'cancelled/declined',
          category: Notification::CANCELED_DECLINED
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
        return Notification::NONE_OF_THE_ABOVE if enrollment_status.blank?

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

        Notification::NONE_OF_THE_ABOVE
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
