# frozen_string_literal: true

module TravelPay
  class BaseExpense
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    attribute :purchase_date, :datetime
    attribute :description, :string
    attribute :cost_requested, :float
    attribute :claim_id, :string

    # Receipt attribute accessor
    attr_accessor :receipt

    validates :purchase_date, presence: true
    validates :description, presence: true, length: { maximum: 255 }
    validates :cost_requested, presence: true, numericality: { greater_than: 0 }

    # Custom belongs_to association with Claim
    #
    # @return [Object, nil] the associated claim object or nil if not found
    def claim
      return nil unless claim_id

      @claim ||= find_claim_by_id(claim_id)
    end

    # Setter for claim association
    # Accepts a claim object and extracts its ID
    #
    # @param claim_obj [Object] the claim object to associate
    def claim=(claim_obj)
      @claim = claim_obj
      self.claim_id = claim_obj&.id
    end

    # Custom has_one association with Receipt
    #
    # @return [Object, nil] the associated receipt or nil
    def receipt_association
      receipt
    end

    # Returns whether the expense has an associated receipt
    #
    # @return [Boolean] true if receipt is present, false otherwise
    def receipt?
      receipt.present?
    end

    # Returns a hash representation of the expense
    #
    # @return [Hash] hash representation of the expense
    def to_h
      result = attributes.dup
      result['claim_id'] = claim_id
      result['has_receipt'] = receipt?
      result['receipt'] = receipt if receipt?
      result['expense_type'] = expense_type
      result
    end

    # Returns the expense type - overridable in subclasses
    # Default implementation returns "other" for the base class
    #
    # @return [String] the expense type
    def expense_type
      'other'
    end

    private

    # Finds a claim by ID - this will need to be implemented based on
    # which claim model is being used in the travel pay system
    #
    # @param id [String] the claim ID to search for
    # @return [Object, nil] the claim object or nil if not found
    def find_claim_by_id(id)
      # TODO: Implementation depends on which Claim model is being used
      # This could be integrated with existing travel pay claim services
      # For now, returning nil as a safe default
      Rails.logger.debug { "BaseExpense: Looking for claim with ID #{id}" }
      nil
    end
  end
end
