# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequest < ApplicationRecord
    EXPIRY_DURATION = 60.days

    belongs_to :claimant, class_name: 'UserAccount'

    has_one :power_of_attorney_form,
            inverse_of: :power_of_attorney_request,
            required: true

    # TODO: Enforce this in the DB.
    has_one :power_of_attorney_form_submission

    has_one :resolution,
            class_name: 'PowerOfAttorneyRequestResolution',
            inverse_of: :power_of_attorney_request

    has_many :notifications,
             class_name: 'PowerOfAttorneyRequestNotification',
             inverse_of: :power_of_attorney_request

    belongs_to :accredited_organization, class_name: 'Veteran::Service::Organization',
                                         foreign_key: :power_of_attorney_holder_poa_code,
                                         primary_key: :poa,
                                         optional: true,
                                         inverse_of: :accredited_organization

    belongs_to :accredited_individual, class_name: 'Veteran::Service::Representative',
                                       foreign_key: :accredited_individual_registration_number,
                                       primary_key: :representative_id,
                                       optional: true,
                                       inverse_of: :power_of_attorney_requests

    before_validation :set_claimant_type

    module ClaimantTypes
      ALL = [
        DEPENDENT = 'dependent',
        VETERAN = 'veteran'
      ].freeze
    end

    enum(
      :claimant_type,
      ClaimantTypes::ALL.index_by(&:itself),
      validate: true
    )

    validates :power_of_attorney_holder_type, inclusion: { in: PowerOfAttorneyHolder::Types::ALL }

    accepts_nested_attributes_for :power_of_attorney_form

    def expires_at
      created_at + EXPIRY_DURATION if unresolved?
    end

    def unresolved?
      !resolved?
    end

    def resolved?
      resolution.present?
    end

    def accepted?
      resolved? && resolution.resolving.is_a?(PowerOfAttorneyRequestDecision) &&
        resolution.resolving.type == PowerOfAttorneyRequestDecision::Types::ACCEPTANCE
    end

    def declined?
      resolved? && resolution.resolving.is_a?(PowerOfAttorneyRequestDecision) &&
        resolution.resolving.type == PowerOfAttorneyRequestDecision::Types::DECLINATION
    end

    def expired?
      resolved? && resolution.resolving.is_a?(PowerOfAttorneyRequestExpiration)
    end

    def replaced?
      resolved? && resolution.resolving.is_a?(PowerOfAttorneyRequestWithdrawal) &&
        resolution.resolving.type == PowerOfAttorneyRequestWithdrawal::Types::REPLACEMENT
    end

    def mark_accepted!(creator, reason)
      PowerOfAttorneyRequestDecision.create_acceptance!(
        creator:, power_of_attorney_request: self, reason:
      )
    end

    def mark_declined!(creator, declination_reason)
      PowerOfAttorneyRequestDecision.create_declination!(
        creator:,
        power_of_attorney_request: self,
        declination_reason:
      )
    rescue => e
      Rails.logger.error("Error creating declination: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    end

    def mark_replaced!(superseding_power_of_attorney_request)
      PowerOfAttorneyRequestWithdrawal.create_replacement!(
        power_of_attorney_request: self,
        superseding_power_of_attorney_request:
      )
    end

    # We're using just the timestamp for convenience and speed. Direct queries
    # against the redacted fields will always be authoritative
    scope :unredacted, -> { where(redacted_at: nil) }
    scope :redacted, -> { where.not(redacted_at: nil) }

    scope :unresolved, -> { where.missing(:resolution) }
    scope :resolved, -> { joins(:resolution) }

    scope :decisioned, lambda {
      joins(:resolution)
        .where(
          resolution: {
            resolving_type: PowerOfAttorneyRequestDecision.to_s
          }
        )
    }

    scope :sorted_by, lambda { |sort_column, direction|
      direction = direction&.to_s&.downcase
      normalized_order = %w[asc desc].include?(direction) ? direction : 'asc'
      null_treatment = normalized_order == 'asc' ? 'NULLS LAST' : 'NULLS FIRST'

      case sort_column&.to_s
      when 'created_at'
        order(created_at: normalized_order)
      when 'resolved_at'
        left_outer_joins(:resolution)
          .order(Arel.sql("resolution.created_at #{normalized_order} #{null_treatment}"))
      else
        raise ArgumentError, "Invalid sort column: #{sort_column}"
      end
    }

    concerning :ProcessedScopes do
      processed_join_sql_template = <<~SQL.squish
        LEFT OUTER JOIN "ar_power_of_attorney_request_resolutions" "resolution" ON
          "resolution"."power_of_attorney_request_id" = "ar_power_of_attorney_requests"."id"
        LEFT OUTER JOIN "ar_power_of_attorney_request_decisions" "acceptance" ON
          "resolution"."resolving_type" = :resolving_type AND
          "resolution"."resolving_id" = "acceptance"."id" AND
          "acceptance"."type" = :decision_type
        LEFT OUTER JOIN "ar_power_of_attorney_form_submissions" "succeeded_form_submission" ON
          "succeeded_form_submission"."power_of_attorney_request_id" = "ar_power_of_attorney_requests"."id" AND
          "succeeded_form_submission"."status" = :submission_status
      SQL

      processed_join_sql =
        ApplicationRecord.sanitize_sql(
          [
            processed_join_sql_template,
            { resolving_type: PowerOfAttorneyRequestDecision,
              decision_type: PowerOfAttorneyRequestDecision::Types::ACCEPTANCE,
              submission_status: PowerOfAttorneyFormSubmission::Statuses::SUCCEEDED }
          ]
        )

      ##
      # `processed`and `not_processed` are the logical negation of one another.
      # `invert_where` from `ActiveRecord` is a way to negate SQL where
      # conditions, and it would be nice if we could use it here. But it has
      # the problem of also negating any conditions that were chained earlier in
      # a relation.
      #
      # Moral of the story, if the definition of one of these is updated, the
      # other needs to be too.
      #
      included do
        scope :processed, lambda {
          relation =
            joins(processed_join_sql)

          relation.where.not(resolution: { id: nil }).merge(
            relation.where(resolution: { acceptance: { id: nil } }).or(
              relation.where.not(succeeded_form_submission: { id: nil })
            )
          )
        }

        scope :not_processed, lambda {
          relation =
            joins(processed_join_sql)

          relation.where(resolution: { id: nil }).or(
            relation.where.not(resolution: { acceptance: { id: nil } }).merge(
              relation.where(succeeded_form_submission: { id: nil })
            )
          )
        }
      end
    end

    scope :for_power_of_attorney_holders, lambda { |poa_holders|
      return none if poa_holders.empty?

      prefix = 'power_of_attorney_holder'
      names = PowerOfAttorneyHolder::PRIMARY_KEY_ATTRIBUTE_NAMES
      prefixed_names = names.map { |name| :"#{prefix}_#{name}" }
      values = poa_holders.map { |poa_holder| poa_holder.to_h.values_at(*names) }

      where(prefixed_names => values)
    }

    private

    def set_claimant_type
      self.claimant_type =
        if power_of_attorney_form.parsed_data['dependent']
          ClaimantTypes::DEPENDENT
        elsif power_of_attorney_form.parsed_data['veteran']
          ClaimantTypes::VETERAN
        end
    end
  end
end
