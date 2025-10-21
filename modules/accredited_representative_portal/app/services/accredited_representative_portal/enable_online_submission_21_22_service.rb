# frozen_string_literal: true

module AccreditedRepresentativePortal
  class EnableOnlineSubmission2122Service
    def self.call(poa_codes:)
      codes = normalize_codes(poa_codes)
      raise ArgumentError, 'POA codes required' if codes.empty?

      scope = Veteran::Service::Organization
              .where(poa: codes)
              .where.not(can_accept_digital_poa_requests: true)

      # rubocop:disable Rails/SkipsModelValidations
      scope.update_all(can_accept_digital_poa_requests: true)
      # rubocop:enable Rails/SkipsModelValidations
    end

    def self.normalize_codes(input)
      Array(input)
        .flat_map { |c| c.to_s.split(',') }
        .map(&:strip)
        .compact_blank
        .uniq
    end
    private_class_method :normalize_codes
  end
end
