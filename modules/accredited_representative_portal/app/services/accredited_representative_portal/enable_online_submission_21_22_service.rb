# frozen_string_literal: true

module AccreditedRepresentativePortal
  class EnableOnlineSubmission2122Service
    def self.call(poa_codes:)
      codes = normalize_codes(poa_codes)
      raise ArgumentError, 'POA codes required' if codes.empty?

      org_scope = Veteran::Service::Organization.where(poa: codes)
      orgs_to_update = org_scope.where.not(can_accept_digital_poa_requests: true)

      orgs_updated = 0
      orgs_to_update.find_each do |vso|
        orgs_updated += 1 if vso.update(can_accept_digital_poa_requests: true)
      end

      reps_updated =
        Veteran::Service::OrganizationRepresentative
        .active
        .where(organization_poa: org_scope.select(:poa))
        .where.not(
          acceptance_mode: Veteran::Service::OrganizationRepresentative
            .acceptance_modes[:any_request]
        )
        .update_all(
          acceptance_mode: Veteran::Service::OrganizationRepresentative
            .acceptance_modes[:any_request]
        )

      {
        orgs_updated:,
        reps_updated:
      }
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
