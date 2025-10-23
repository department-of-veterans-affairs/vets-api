# frozen_string_literal: true

module AccreditedRepresentativePortal
  class EnableOnlineSubmission2122Service
    def self.call(poa_codes:)
      codes = normalize_codes(poa_codes)
      raise ArgumentError, 'POA codes required' if codes.empty?

      scope = Veteran::Service::Organization
              .where(poa: codes)
              .where.not(can_accept_digital_poa_requests: true)

      updated = 0

      scope.each { |vso| updated += 1 if vso.update(can_accept_digital_poa_requests: true) }

      updated
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
