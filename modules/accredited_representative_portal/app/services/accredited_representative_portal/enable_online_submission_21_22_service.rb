# frozen_string_literal: true

module AccreditedRepresentativePortal
  class EnableOnlineSubmission2122Service
    def self.call(poa_codes:)
      codes = normalize_codes(poa_codes)
      raise ArgumentError, 'POA codes required' if codes.empty?

      # One scope: only rows that actually need the flip
      matched_orgs = Veteran::Service::Organization
                     .where(poa: codes)
                     .where.not(can_accept_digital_poa_requests: true)

      matched_count = matched_orgs.count

      # rubocop:disable Rails/SkipsModelValidations
      updated_count = matched_orgs.update_all(can_accept_digital_poa_requests: true)
      # rubocop:enable Rails/SkipsModelValidations

      # In the single-scope design, "matched_count" == rows that needed updating.
      { poa_codes: codes, matched_count:, updated_count: }
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
