# frozen_string_literal: true

module AccreditedRepresentativePortal
  class EmailPersonalisations
    class << self
      def generate(notification)
        new(notification).generate
      end
    end

    def generate
      {
        'first_name' => first_name
      }
    end

    def initialize(notification)
      @notification = notification
    end

    private

    def first_name
      @notification.claimant_hash.dig('name', 'first')
    end

    class Requested < self
      def generate
        {
          'first_name' => first_name,
          'last_name' => last_name,
          'submit_date' => submit_date,
          'expiration_date' => expiration_date,
          'representative_name' => representative_name
        }
      end

      private

      def base_time
        Time.zone.now.in_time_zone('Eastern Time (US & Canada)')
      end

      def expiration_date
        (base_time + 60.days).strftime('%B %d, %Y')
      end

      def last_name
        @notification.claimant_hash.dig('name', 'last')
      end

      def representative_name
        accredited_individual = @notification.accredited_individual
        accredited_organization = @notification.accredited_organization
        if accredited_individual.present? && accredited_organization.present?
          "#{accredited_individual.full_name.strip} accredited with #{accredited_organization.name.strip}"
        elsif accredited_individual.present?
          accredited_individual.full_name.strip
        else
          accredited_organization.name.strip
        end
      end

      def submit_date
        base_time.strftime('%B %d, %Y')
      end
    end

    class Declined < self
      DECLINATION_REASON_TEXTS = {
        DECLINATION_HEALTH_RECORDS_WITHHELD: 'you didn\'t provide access to health records',
        DECLINATION_ADDRESS_CHANGE_WITHHELD: 'you didn\'t allow changes to address',
        DECLINATION_BOTH_WITHHELD:
          'you didn\'t allow changes to address or access to health records',
        DECLINATION_NOT_ACCEPTING_CLIENTS: 'the VSO is not currently accepting new clients',
      }.freeze

      def generate
        {
          'first_name' => first_name,
          'declination_text' => declination_text.to_s
        }
      end
      private
        def declination_text
          return '' if declination_reason == 'DECLINATION_OTHER'

          "The reason given was #{DECLINATION_REASON_TEXTS[declination_reason.to_sym]}"
        end
        def declination_reason
          @notification.power_of_attorney_request.resolution.resolving.declination_reason
        end
    end

    class Expiring < self
    end

    class Expired < self
    end
  end
end
