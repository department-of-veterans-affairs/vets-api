# frozen_string_literal: true

module ConvertFileType
  extend ActiveSupport::Concern

  class_methods do
    def tiff?(mimemagic_object: nil, carrier_wave_sanitized_file: nil)
      return mimemagic_object.type == 'image/tiff' if mimemagic_object

      carrier_wave_sanitized_file&.content_type == 'image/tiff'
    end

    def incorrect_extension?(extension:, mimemagic_object:)
      extension = extension.to_s.downcase
      true_extensions = extensions_from_mimemagic_object(mimemagic_object).map(&:downcase)
      true_extensions.present? && !extension.in?(true_extensions)
    end

    def extensions_from_mimemagic_object(mimemagic_object)
      mimemagic_object&.extensions || []
    end

    def inspect_binary(carrier_wave_sanitized_file)
      file_obj = carrier_wave_sanitized_file&.to_file
      file_obj && MimeMagic.by_magic(file_obj)
    ensure
      file_obj.close if file_obj.respond_to? :close
    end
  end

  def converted_exists?
    converted.present? && converted.file.exists?
  end

  def final_filename
    if converted_exists?
      converted.file.filename
    else
      file.filename
    end
  end

  def read_for_upload
    if converted_exists?
      converted.read
    else
      read
    end
  end

  private

  def tiff?(carrier_wave_sanitized_file)
    self.class.tiff?(
      carrier_wave_sanitized_file:,
      mimemagic_object: self.class.inspect_binary(carrier_wave_sanitized_file)
    )
  end

  def tiff_or_incorrect_extension?(carrier_wave_sanitized_file)
    mimemagic_object = self.class.inspect_binary carrier_wave_sanitized_file
    self.class.tiff?(
      carrier_wave_sanitized_file:,
      mimemagic_object:
    ) || self.class.incorrect_extension?(
      extension: carrier_wave_sanitized_file.extension,
      mimemagic_object:
    )
  end
end
