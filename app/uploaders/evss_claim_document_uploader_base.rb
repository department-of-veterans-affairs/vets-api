# frozen_string_literal: true

class EVSSClaimDocumentUploaderBase < CarrierWave::Uploader::Base
  include SetAWSConfig
  include ValidatePdf
  include CarrierWave::MiniMagick
  include ConvertFileType

  version :converted, if: :tiff_or_incorrect_extension? do
    process(convert: :jpg, if: :tiff?)
    def full_filename(original_name_for_file)
      name = "converted_#{original_name_for_file}"
      extension = CarrierWave::SanitizedFile.new(nil).send(:split_extension, original_name_for_file)[1]
      mimemagic_object = self.class.inspect_binary file
      if self.class.incorrect_extension?(extension:, mimemagic_object:)
        extension = self.class.extensions_from_mimemagic_object(mimemagic_object).max
        return "#{name.gsub('.', '_')}.#{extension}"
      end
      name
    end
  end

  before :store, :validate_file_size

  def size_range
    1.byte...150.megabytes
  end

  def extension_allowlist
    %w[pdf gif png tiff tif jpeg jpg bmp txt]
  end

  def max_file_size_non_pdf
    50.megabytes
  end

  # EVSS will split PDF's larger than 50mb before sending to VBA who has a limit of 50mb. so,
  # PDF's can be larger than other files
  def validate_file_size(file)
    if file.content_type != 'application/pdf' && file.size > max_file_size_non_pdf
      raise CarrierWave::IntegrityError, I18n.t(:'errors.messages.max_size_error',
                                                max_size: '50MB')
    end
  end
end
