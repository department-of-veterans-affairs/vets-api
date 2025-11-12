# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SavedClaimClaimantRepresentative < ApplicationRecord
    belongs_to :saved_claim, class_name: '::SavedClaim'

    before_validation :set_claimant_type
    validates :power_of_attorney_holder_type, inclusion: { in: PowerOfAttorneyHolder::Types::ALL }

    ##
    # TODO: Extract a common constant?
    #
    ClaimantTypes = PowerOfAttorneyRequest::ClaimantTypes

    enum(
      :claimant_type,
      ClaimantTypes::ALL.index_by(&:itself),
      validate: true
    )

    delegate :form_id, :display_form_id, :parsed_form, :claimant_info, :persistent_attachments,
             :guid, :latest_submission_attempt, :pending_submission_attempt_stale?, to: :saved_claim

    scope :for_power_of_attorney_holders, lambda { |poa_holders|
      return none if poa_holders.empty?

      prefix = 'power_of_attorney_holder'
      names = PowerOfAttorneyHolder::PRIMARY_KEY_ATTRIBUTE_NAMES
      prefixed_names = names.map { |name| :"#{prefix}_#{name}" }
      values = poa_holders.map { |poa_holder| poa_holder.to_h.values_at(*names) }

      where(prefixed_names => values)
    }

    scope :sorted_by, lambda { |sort_column, direction|
      direction = direction&.to_s&.downcase
      normalized_order = %w[asc desc].include?(direction) ? direction : 'asc'

      case sort_column&.to_s
      when 'created_at'
        order(created_at: normalized_order)
      else
        raise ArgumentError, "Invalid sort column: #{sort_column}"
      end
    }

    private

    def set_claimant_type
      self.claimant_type =
        if saved_claim.parsed_form['dependent']
          ClaimantTypes::DEPENDENT
        elsif saved_claim.parsed_form['veteran']
          ClaimantTypes::VETERAN
        end
    end
  end
end
