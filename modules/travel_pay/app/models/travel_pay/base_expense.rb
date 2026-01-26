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

    validates :purchase_date, presence: true, unless: -> { is_a?(MileageExpense) }
    validates :description, length: { maximum: 2000 }, allow_nil: true, unless: -> { is_a?(MileageExpense) }
    validates :cost_requested, presence: true, numericality: { greater_than: 0 }, unless: -> { is_a?(MileageExpense) }

    # Returns the list of permitted parameters for this expense type
    # Subclasses can override completely or extend with super + [...]
    #
    # @return [Array<Symbol>] list of permitted parameter names
    def self.permitted_params
      %i[purchase_date description cost_requested receipt]
    end

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
      result['receipt'] = hashify_receipt(receipt) if receipt?
      result['expense_type'] = expense_type
      result
    end

    ### TODO Clean this up
    def hashify_receipt(r)
      result = {}
      result['contentType'] = r['content_type'] || r[:content_type]
      result['length'] = r['length'] || r[:length]
      result['fileName'] = r['file_name'] || r[:file_name]
      result['fileData'] = r['file_data'] || r[:file_data]
      result
    end

    # Returns the expense type - overridable in subclasses
    # Default implementation returns "other" for the base class
    #
    # @return [String] the expense type
    def expense_type
      'other'
    end

    # Returns a hash of parameters formatted for the service layer
    # Subclasses can override completely or extend with super.merge(...)
    #
    # @return [Hash] parameters formatted for the service
    def to_service_params
      params = {
        'expense_type' => expense_type,
        'purchase_date' => format_date(purchase_date),
        'description' => description,
        'cost_requested' => cost_requested
      }
      params['claim_id'] = claim_id if claim_id.present?
      params['receipt'] = hashify_receipt(receipt) if receipt.present?
      params
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

    # Formats a date/datetime value as ISO8601 string for the service layer
    #
    # @param date [Date, Time, DateTime, String, nil] the date to format
    # @return [String, nil] ISO8601 formatted date string or nil
    def format_date(date)
      return nil if date.nil?

      if date.is_a?(Date) || date.is_a?(Time) || date.is_a?(DateTime)
        date.iso8601
      elsif date.is_a?(String)
        begin
          Date.iso8601(date).iso8601
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
