# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequest < ApplicationRecord
    EXPIRY_DURATION = 60.days

    belongs_to :claimant, class_name: 'UserAccount'

    has_one :power_of_attorney_form,
            inverse_of: :power_of_attorney_request,
            required: true # for now

    # TODO: Enforce this in the DB.
    has_one :power_of_attorney_form_submission

    has_one :resolution,
            class_name: 'PowerOfAttorneyRequestResolution',
            inverse_of: :power_of_attorney_request

    belongs_to :accredited_organization, class_name: 'Veteran::Service::Organization',
                                         foreign_key: :power_of_attorney_holder_poa_code,
                                         primary_key: :poa,
                                         optional: true

    belongs_to :accredited_individual, class_name: 'Veteran::Service::Representative',
                                       foreign_key: :accredited_individual_registration_number,
                                       primary_key: :representative_id,
                                       optional: true

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

    ##
    # This `concerning` block puts up some flashing lights around this
    # complexity. It potentially wants to coexist directly with other model
    # functionality or at a higher business logic layer, but extra care might be
    # needed to pull that off without making a mess. This block is especially
    # narrow--it only defines two scopes and no instance methods for example.
    #
    concerning :ProcessedScopes do
      ##
      # The 3x `LEFT OUTER JOIN`s with very particular join conditions make
      # expressing both of the `processed` and `not_processed` relations easy
      # to express with very simple `WHERE` conditions.
      #
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
      # `processed` and `not_processed` are the logical negation of one another,
      # but this isn't enforced structurally in the code. An application of De
      # Morgan's law is evident here. `invert_where` is a possibility to pull
      # this off too, but it's not so usable because it inverts conditions that
      # were chained prior.
      #
      included do
        scope :processed, lambda {
          ##
          # Must be resolved, and either the resolution is not an acceptance, or if
          # it is, there must be a form submission that succeeded.
          #
          relation =
            joins(processed_join_sql)

          relation.where.not(resolution: { id: nil }).merge(
            relation.where(resolution: { acceptance: { id: nil } }).or(
              relation.where.not(succeeded_form_submission: { id: nil })
            )
          )
        }

        scope :not_processed, lambda {
          ##
          # Must be unresolved, or the resolution is an acceptance and there also
          # must not be a form submission that succeeded.
          #
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
