# frozen_string_literal: true

module SOB
  module DGIB
    class Response
      include Vets::Model

      attribute :first_name, String
      attribute :last_name, String
      attribute :date_of_birth, String
      attribute :va_file_number, String
      attribute :regional_processing_office, String
      attribute :active_duty, Bool
      attribute :veteran_is_eligible, Bool
      attribute :eligibility_date, String
      attribute :delimiting_date, String
      attribute :percentage_benefit, Integer
      attribute :original_entitlement, Entitlement
      attribute :used_entitlement, Entitlement
      attribute :remaining_entitlement, Entitlement
      attribute :entitlement_transferred_out, Entitlement

      def initialize(_status, response = nil)
        @claimant = response&.body&.dig('claimant')
        super(normalized_attributes) if @claimant
      end

      private

      def normalized_attributes
        @claimant['date_of_birth'] = parse_date(@claimant['date_of_birth'])
        @claimant['regional_processing_office'] = parse_rpo(@claimant['station'])
        benefit = find_benefit(@claimant['benefits'])
        return @claimant unless benefit

        parse_eligibility(benefit['eligibility_results'])
        parse_entitlement(benefit['entitlement_results'])
        parse_toe(benefit['entitlement_transfer_out'])

        @claimant
      end

      RPO_MAP = {
        'RPO307' => 'Buffalo, NY',
        'RPO316' => 'Atlanta, GA',
        'RPO331' => 'St. Louis, MO',
        'RPO351' => 'Muskogee, OK',
        'VACentralOffice' => 'Central Office Washington, DC'
      }.freeze

      def parse_rpo(rpo_code)
        RPO_MAP[rpo_code]
      end

      def parse_date(date_string)
        date_string&.to_date&.iso8601
      end

      def find_benefit(list)
        list.find { |item| item['benefit_type'] == SOB::DGIB::Service::BENEFIT_TYPE }
      end

      # is eligibility results list sorted by most recent? don't understand why list
      def parse_eligibility(eligibilities)
        eligibility = eligibilities.first
        return unless eligibility

        @claimant.merge!(eligibility.slice('active_duty',
                                           'veteran_is_eligible',
                                           'percentage_benefit'))
        @claimant.merge!(
          eligibility['eligibility_period']
            &.slice('eligibility_date', 'delimiting_date')
            &.transform_values(&method(:parse_date))
        )
      end

      ENTITLEMENT_KEY_MAP = {
        'orig_entitled_days' => 'original_entitlement',
        'days_used' => 'used_entitlement',
        'days_remaining' => 'remaining_entitlement'
      }.freeze

      def parse_entitlement(entitlements)
        entitlement = find_benefit(entitlements)
        return unless entitlement

        ENTITLEMENT_KEY_MAP.each do |res_key, vets_key|
          days = entitlement[res_key]
          @claimant[vets_key] = parse_months(days)
        end
      end

      def parse_toe(transfers)
        transfer = find_benefit(transfers)
        return unless transfer

        @claimant['entitlement_transferred_out'] = parse_months(
          transfer['transferred_days']
        )
      end

      def parse_months(days)
        return unless days

        {
          months: days / 30,
          days: days % 30
        }
      end
    end
  end
end
