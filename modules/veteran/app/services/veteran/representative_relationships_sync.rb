# frozen_string_literal: true

module Veteran
  class RepresentativeRelationshipsSync
    class << self
      def sync!(rep_org_pairs:, current_poa_codes:)
        new.sync!(rep_org_pairs:, current_poa_codes:)
      end
    end

    def sync!(rep_org_pairs:, current_poa_codes:)
      pairs = rep_org_pairs.compact.uniq
      return if pairs.empty? || current_poa_codes.blank?

      org_accept_map = organization_accept_map(current_poa_codes)
      rows = build_org_rep_rows(pairs, org_accept_map)

      insert_missing_org_rep_rows(rows) if rows.any?
      sync_org_rep_active_status!(pairs:, poa_codes: current_poa_codes)
      deactivate_stale_organization_joins(current_poa_codes)
    end

    private

    def organization_accept_map(poa_codes)
      Veteran::Service::Organization
        .where(poa: poa_codes)
        .pluck(:poa, :can_accept_digital_poa_requests)
        .to_h
    end

    def build_org_rep_rows(pairs, org_accept_map)
      pairs.filter_map do |rep_id, poa|
        next if rep_id.blank? || poa.blank?

        acceptance_mode = org_accept_map.fetch(poa, false) ? 'any_request' : 'no_acceptance'

        {
          representative_id: rep_id,
          organization_poa: poa,
          acceptance_mode:
        }
      end
    end

    # NOTE: We intentionally use `insert_all` with a unique constraint on
    # [:organization_poa, :representative_id] so ingestion is idempotent.
    #
    # This behaves like `INSERT ... ON CONFLICT DO NOTHING`:
    # - If a (organization, representative) join row does NOT exist yet,
    #   it is inserted and `acceptance_mode` is seeded from the
    #   organization-wide `can_accept_digital_poa_requests` flag.
    #
    # - If the join row already exists (including cases where
    #   `acceptance_mode` was manually changed later),
    #   the insert conflicts and does nothing.
    #
    # This prevents ingestion from overwriting per-representative
    # `acceptance_mode` once it has been explicitly set.
    #
    # rubocop:disable Rails/SkipsModelValidations
    def insert_missing_org_rep_rows(rows)
      Veteran::Service::OrganizationRepresentative.insert_all(
        rows,
        unique_by: %i[organization_poa representative_id]
      )
    end
    # rubocop:enable Rails/SkipsModelValidations

    def sync_org_rep_active_status!(pairs:, poa_codes:)
      reactivate_org_rep_pairs!(pairs)
      deactivate_missing_org_rep_pairs!(pairs, poa_codes)
    end

    # rubocop:disable Rails/SkipsModelValidations
    def reactivate_org_rep_pairs!(pairs)
      pairs.each_slice(1000) do |slice|
        conditions = slice.map { |_| '(organization_poa = ? AND representative_id = ?)' }.join(' OR ')
        binds = slice.flat_map { |rep_id, poa| [poa, rep_id] }

        Veteran::Service::OrganizationRepresentative
          .where.not(deactivated_at: nil)
          .where(conditions, *binds)
          .update_all(deactivated_at: nil)
      end
    end
    # rubocop:enable Rails/SkipsModelValidations

    # rubocop:disable Rails/SkipsModelValidations
    def deactivate_missing_org_rep_pairs!(pairs, poa_codes)
      expected = pairs.to_set { |rep_id, poa| [poa, rep_id] }
      now = Time.current

      ids_to_deactivate = []

      Veteran::Service::OrganizationRepresentative
        .where(organization_poa: poa_codes, deactivated_at: nil)
        .select(:id, :organization_poa, :representative_id)
        .find_each do |join|
          key = [join.organization_poa, join.representative_id]
          ids_to_deactivate << join.id unless expected.include?(key)
        end

      return if ids_to_deactivate.empty?

      ids_to_deactivate.each_slice(1000) do |slice|
        Veteran::Service::OrganizationRepresentative
          .where(id: slice)
          .update_all(deactivated_at: now)
      end
    end
    # rubocop:enable Rails/SkipsModelValidations

    # Retain stale orgs that are no longer in the OGC data, but deactivate their join records
    # rubocop:disable Rails/SkipsModelValidations
    def deactivate_stale_organization_joins(current_poa_codes)
      return if current_poa_codes.blank?

      stale_poas = Veteran::Service::Organization.where.not(poa: current_poa_codes).pluck(:poa)
      return if stale_poas.empty?

      Veteran::Service::OrganizationRepresentative
        .where(organization_poa: stale_poas, deactivated_at: nil)
        .update_all(deactivated_at: Time.current)
    end
    # rubocop:enable Rails/SkipsModelValidations
  end
end
