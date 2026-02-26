# frozen_string_literal: true

require 'mini_magick'
require 'base64'

module TravelPay
  ##
  # Converts HEIC/HEIF receipt images to JPG format.
  #
  class ReceiptConverter
    # Processes expense params and converts HEIC receipt to JPG if present
    #
    # @param params [Hash] expense params hash that may contain a 'receipt' key
    # @return [Hash] params with receipt converted to JPG if it was HEIC/HEIF
    # @raise [Common::Exceptions::UnprocessableEntity] if conversion fails
    def convert_if_heic(params)
      receipt = params['expenseReceipt']
      return params unless receipt.present? && heic_image?(receipt['contentType'])

      unless Flipper.enabled?(:travel_pay_enable_heic_conversion)
        Rails.logger.warn("Unsupported HEIC/HEIF receipt rejected: #{receipt['fileName']}")
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: 'HEIC/HEIF images are not currently supported. Please convert to JPG or PNG before uploading.'
        )
      end

      Rails.logger.info('Converting HEIC receipt to JPG')

      converted_receipt = convert_heic_to_jpg(receipt)
      params.merge('expenseReceipt' => converted_receipt)
    rescue Common::Exceptions::UnprocessableEntity
      raise
    rescue => e
      error_message = "HEIC conversion failed: #{e.message}"
      Rails.logger.error(error_message)
      raise Common::Exceptions::UnprocessableEntity.new(detail: error_message)
    end

    private

    # Checks if the content type is HEIC/HEIF format
    #
    # @param content_type [String, nil] the content type to check
    # @return [Boolean] true if content type is HEIC/HEIF
    def heic_image?(content_type)
      content_type.to_s.match?(%r{^image/(heic|heif)$}i)
    end

    # Converts a HEIC receipt hash to JPG format
    #
    # @param receipt [Hash] receipt hash with camelCase keys (contentType, fileData, etc.)
    # @return [Hash] updated receipt hash with JPG data
    def convert_heic_to_jpg(receipt)
      file_data = receipt['fileData']
      return receipt if file_data.blank?

      jpg_binary = convert_image_to_jpg(Base64.strict_decode64(file_data))

      receipt.merge(
        'fileData' => Base64.strict_encode64(jpg_binary),
        'contentType' => 'image/jpeg',
        'length' => jpg_binary.bytesize.to_s,
        'fileName' => receipt['fileName']&.sub(/\.hei[cf]$/i, '.jpg')
      ).tap do
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
  end
end
