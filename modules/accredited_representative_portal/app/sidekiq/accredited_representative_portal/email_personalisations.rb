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
    end

    class Expiring < self
    end

    class Expired < self
    end
  end
end
