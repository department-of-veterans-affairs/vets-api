# frozen_string_literal: true

module SOB
  module DGI
    class Response
      include Vets::Model

      class Ch33DataMissing < StandardError; end

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

      RPO_MAP = {
        'RPO307' => 'Buffalo, NY',
        'RPO316' => 'Atlanta, GA',
        'RPO331' => 'St. Louis, MO',
        'RPO351' => 'Muskogee, OK',
        'VACentralOffice' => 'Central Office Washington, DC'
      }.freeze

      def normalized_attributes
        @claimant['date_of_birth'] = parse_date(@claimant['date_of_birth'])
        @claimant['regional_processing_office'] = RPO_MAP[@claimant['station']]
        benefit = @claimant['benefits'].find { |b| b['benefit_type'] == Service::BENEFIT_TYPE }
        # Guard against case where we have 200 response but empty benefits list
        raise Ch33DataMissing unless benefit

        parse_eligibility(benefit['eligibility_results'])
        parse_entitlement(benefit['entitlement_results'])
        parse_toe(benefit['entitlement_transfer_out'])

        @claimant
      end

      def parse_date(date_string)
        date_string&.to_date&.iso8601
      end

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
        entitlement = entitlements.first
        return unless entitlement

        ENTITLEMENT_KEY_MAP.each do |res_key, vets_key|
          days = entitlement[res_key]
          @claimant[vets_key] = parse_months(days)
        end
      end

      def parse_toe(transfers)
        transferred_days = transfers&.inject(0) do |total, transfer|
          total + (transfer['transferred_days'] || 0)
        end

        return if transferred_days.zero?

        @claimant['entitlement_transferred_out'] = parse_months(transferred_days)
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
