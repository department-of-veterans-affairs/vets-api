# frozen_string_literal: true

module AccreditedRepresentativePortal
  class EnableOnlineSubmission2122Service
    def self.call(poa_codes:)
      codes = normalize_codes(poa_codes)
      raise ArgumentError, 'POA codes required' if codes.empty?

      orgs = organizations_for(codes)

      {
        orgs_updated: enable_online_submission!(orgs),
        reps_updated: set_active_reps_mode!(orgs, 'any_request')
      }
    end

    def self.organizations_for(codes)
      Veteran::Service::Organization.where(poa: codes)
    end
    private_class_method :organizations_for

    def self.enable_online_submission!(org_scope)
      orgs_to_update = org_scope.where.not(can_accept_digital_poa_requests: true)

      updated = 0
      orgs_to_update.find_each do |vso|
        updated += 1 if vso.update(can_accept_digital_poa_requests: true)
      end

      updated
    end
    private_class_method :enable_online_submission!

    def self.set_active_reps_mode!(org_scope, mode)
      reps_scope =
        Veteran::Service::OrganizationRepresentative
          .active
          .where(organization_poa: org_scope.select(:poa))
          .where.not(acceptance_mode: mode)

      updated = 0
      reps_scope.find_each do |org_rep|
        org_rep.update!(acceptance_mode: mode)
        updated += 1
      end

      updated
    end
    private_class_method :set_active_reps_mode!

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
