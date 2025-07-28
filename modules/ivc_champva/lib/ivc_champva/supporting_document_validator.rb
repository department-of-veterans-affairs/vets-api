# frozen_string_literal: true

require 'common/file_helpers'
require_relative 'document_ocr_validators'

module IvcChampva
  class SupportingDocumentValidator
    attr_reader :file_path, :form_uuid, :attachment_id, :extracted_text

    # Map attachment IDs to their corresponding validators
    # Some attachment IDs are not provided by the UI, so they will be iterated over to determine suitability
    VALIDATOR_MAP = {
      # Not expecting Social Security cards for now - skip to save performance
      # 'Social Security card' => DocumentOcrValidators::Tesseract::SocialSecurityCardTesseractValidator,
      'EOB' => DocumentOcrValidators::Tesseract::EobTesseractValidator,
      'medical invoice' => DocumentOcrValidators::Tesseract::SuperbillTesseractValidator,
      'pharmacy invoice' => DocumentOcrValidators::Tesseract::PharmacyClaimTesseractValidator
    }.freeze

    def initialize(file_path, form_uuid, attachment_id:)
      @file_path = file_path
      @form_uuid = form_uuid
      @attachment_id = attachment_id
      @extracted_text = nil
    end

    def process
      # Extract text from the document
      perform_ocr

      # Get a validator for the attachment ID
      validator = get_validator_for_attachment_id

      # If no validator is found, find the validator with the highest confidence score
      validator ||= find_best_validator_by_confidence

      return default_result unless validator

      # Use cached results from the validator to avoid recomputation
      {
        validator_type: validator.class.name,
        document_type: validator.document_type,
        attachment_id: @attachment_id,
        is_valid: validator.cached_validity,
        extracted_fields: validator.cached_extracted_fields,
        confidence: validator.cached_confidence_score
      }
    end

    private

    def perform_ocr
      return @extracted_text if @extracted_text

      image_path = prepare_image_for_ocr
      @extracted_text = RTesseract.new(image_path).to_s
    ensure
      FileUtils.rm_f(image_path) if image_path && File.exist?(image_path)
    end

    def prepare_image_for_ocr
      image_path = Rails.root.join("#{Common::FileHelpers.random_file_path}.jpg").to_s

      if pdf_file?
        convert_pdf_to_image(image_path)
      else
        # For image files, copy to the working path
        FileUtils.cp(@file_path, image_path)
      end

      image_path
    end

    def convert_pdf_to_image(output_path)
      pdf = MiniMagick::Image.open(@file_path)
      convert = MiniMagick::Tool.new('convert')
      convert.background 'white'
      convert.flatten
      convert.density 150
      convert.quality 100
      convert << pdf.pages.first.path
      convert << output_path
      convert.call
    end

    def pdf_file?
      File.extname(@file_path).downcase == '.pdf'
    end

    def get_validator_for_attachment_id
      validator_class = VALIDATOR_MAP[@attachment_id]
      return nil unless validator_class

      validator = validator_class.new
      # Process and cache results if suitable
      validator.process_and_cache(extracted_text)
      validator.results_cached? ? validator : nil
    end

    def find_best_validator_by_confidence
      best_validator = nil
      best_confidence = 0.0

      VALIDATOR_MAP.each_value do |validator_class|
        validator = validator_class.new

        # If validator is suitable for document, compute confidence; keep if best
        confidence = validator.process_and_cache(extracted_text)
        next unless confidence # Skip if not suitable (returns nil)

        if confidence > best_confidence
          best_confidence = confidence
          best_validator = validator
        end
      end

      best_validator
    end

    def default_result
      {
        validator_type: nil,
        document_type: 'unknown',
        attachment_id: @attachment_id,
        is_valid: false,
        extracted_fields: {},
        confidence: 0.0
      }
    end
  end
end
