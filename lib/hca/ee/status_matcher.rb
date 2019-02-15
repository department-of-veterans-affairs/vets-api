module HCA
  module EE
    module StatusMatcher
      module_function

      CATEGORIES = [
        {
          enrollment_status: 'verified',
          category: :enrolled
        },
        {
          enrollment_status: ['not eligible', 'not eligible; ineligible date'],
          text_matches: [
            {
              category: :inelig_not_enough_time,
              strings: ["24 months", "less than", "24 mos", "24months", "two years"]
            },
            {
              category: :inelig_training_only,
              strings: ["training only", "trng only"],
              acronyms: ["ADT", "ACDUTRA", "ADUTRA"]
            },
            {
              category: :inelig_character_of_discharge,
              strings: ["other than honorable", "dishonorable", "dishonorable for va purposes", "bad conduct", "dis for va pur"],
              acronyms: ['OTH', 'DVA']
            },
            {
              category: :inelig_not_verified,
              strings: ["no proof", "no record", "non-vet", "non vet", "unable to verify", "not a veteran", "214"]
            },
            {
              category: :inelig_guard_reserve,
              strings: ["guard", "reserve", "reservist", "national guard"]
            },
            {
              category: :inelig_champva,
              strings: ['champva']
            },
            {
              category: :inelig_fugitivefelon,
              strings: ['felon']
            },
            {
              category: :inelig_medicare,
              strings: ['medicare']
            },
            {
              category: :inelig_over65,
              strings: ['over 65']
            },
            {
              category: :inelig_citizens,
              strings: ['citizen']
            },
            {
              category: :inelig_filipinoscouts,
              strings: ['filipino']
            },
            {
              category: :rejected_sc_wrongentry,
              strings: ["disability"]
            },
            {
              category: :rejected_inc_wrongentry,
              strings: ['income']
            }
          ]
        },
        {
          enrollment_status: 'not applicable',
          category: :activeduty
        },
        {
          enrollment_status: 'deceased',
          category: :deceased
        },
        {
          enrollment_status: 'closed application',
          category: :closed
        },
        {
          enrollment_status: 'not eligible; refused to pay copay',
          category: :inelig_refusedcopay
        },
        {
          enrollment_status: 'pending; means test required',
          category: :pending_mt
        },
        {
          enrollment_status: 'pending; eligibility status is unverified',
          category: :pending_unverified
        },
        {
          enrollment_status: 'pending; other',
          category: :pending_other
        },
        {
          enrollment_status: 'pending; purple heart unconfirmed',
          category: :pending_purpleheart
        },
        {
          enrollment_status: 'cancelled/declined',
          category: :canceled_declined
        }
      ]

      def parse(enrollment_status, ineligibility_reason = '')
        enrollment_status = enrollment_status.downcase.strip

        CATEGORIES.each do |category_data|
          enrollment_statuses = category_data[:enrollment_status]

          if enrollment_statuses.is_a?(Array)
            next unless enrollment_statuses.include?(enrollment_status)
          else
            next unless enrollment_status == enrollment_statuses
          end

          if category_data[:text_matches]
            category_data[:text_matches].each do |text_match_data|
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
          else
            return category_data[:category]
          end
        end

        if enrollment_status.include?('rejected')
          return :rejected_rightentry
        end

        :none_of_the_above
      end
    end
  end
end

