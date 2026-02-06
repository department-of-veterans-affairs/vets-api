# frozen_string_literal: true

require 'mini_magick'
require 'base64'

module TravelPay
  class BaseExpense
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    attribute :purchase_date, :datetime
    attribute :description, :string
    attribute :cost_requested, :float
    attribute :claim_id, :string

    # Receipt attribute accessor with custom setter for HEIC conversion
    attr_reader :receipt

    validates :purchase_date, presence: true, unless: -> { is_a?(MileageExpense) }
    validates :description, length: { maximum: 2000 }, allow_nil: true, unless: -> { is_a?(MileageExpense) }
    validates :cost_requested, presence: true, numericality: { greater_than: 0 }, unless: -> { is_a?(MileageExpense) }

    # Custom setter for receipt that automatically converts HEIC images to JPG
    #
    # @param receipt_data [Hash, nil] the receipt hash containing file_data, content_type, etc.
    def receipt=(receipt_data)
      @receipt = if receipt_data.nil? || receipt_data.blank?
                   nil
                 elsif Flipper.enabled?(:travel_pay_enable_heic_conversion)
                   process_receipt_with_heic_conversion(receipt_data)
                 else
                   # When disabled: exact same behavior as master
                   receipt_data
                 end
    rescue => e
      Rails.logger.error("Error processing receipt: #{e.message}")
      @receipt = receipt_data
    end

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
      {
        'contentType' => r[:content_type],
        'length' => r[:length],
        'fileName' => r[:file_name],
        'fileData' => r[:file_data]
      }
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

    # Processes receipt data with HEIC conversion support
    #
    # @param receipt_data [Hash] the receipt hash to process
    # @return [Hash] processed receipt hash with potential HEIC to JPG conversion
    def process_receipt_with_heic_conversion(receipt_data)
      receipt_hash = receipt_data.with_indifferent_access

      if heic_image?(receipt_hash[:content_type])
        convert_heic_to_jpg(receipt_hash)
      else
        receipt_data
      end
    end

    # Checks if the content type is HEIC/HEIF format
    #
    # @param content_type [String, nil] the content type to check
    # @return [Boolean] true if content type is HEIC/HEIF
    def heic_image?(content_type)
      content_type.to_s.match?(%r{^image/(heic|heif)$}i)
    end

    # Converts a HEIC image receipt to JPG format
    #
    # @param receipt_hash [Hash] the receipt hash with base64-encoded HEIC data
    # @return [Hash] updated receipt hash with JPG data
    def convert_heic_to_jpg(receipt_hash)
      Rails.logger.info('Converting HEIC receipt to JPG')

      file_data = receipt_hash[:file_data]
      return receipt_hash if file_data.blank?

      jpg_binary = convert_image_to_jpg(Base64.strict_decode64(file_data))

      # Create updated hash without mutating the argument
      receipt_hash.merge(
        file_data: Base64.strict_encode64(jpg_binary),
        content_type: 'image/jpeg',
        length: jpg_binary.bytesize.to_s,
        file_name: receipt_hash[:file_name]&.sub(/\.hei[cf]$/i, '.jpg')
      ).tap do |_updated|
        Rails.logger.info("Successfully converted HEIC to JPG (size: #{jpg_binary.bytesize} bytes)")
      end
    end

    # Converts binary image data to JPG format using MiniMagick
    #
    # @param binary_data [String] binary image data
    # @return [String] JPG binary data
    def convert_image_to_jpg(binary_data)
      image = MiniMagick::Image.read(binary_data)
      image.format('jpg')

      File.binread(image.path)
    ensure
      image&.destroy! if defined?(image) && image
    end

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
