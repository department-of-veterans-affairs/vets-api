# frozen_string_literal: true

module PdfHelpers
  # Converts PDF at path to array of md5's, one md5 for each page of the document.
  # Problem: Taking an md5 of the PDF itself causes a mis-match between the generated and expected PDFs due to
  # differences in metadata.
  #
  # @param [String] path The path to the PDF
  # @param [String] identifier A unique identifier to generate the temporary file path
  # @return [[String]] Array of md5's
  def pdf_to_md5s(path, identifier)
    image_paths = pdf_to_image(path, identifier)

    image_paths.map do |image_path|
      md5 = Digest::MD5.hexdigest(File.read(image_path))
      File.delete(image_path) if File.exist?(image_path)
      md5
    end
  end

  # Converts PDF at path to jpg's
  # @param [String] path The path to the PDF
  # @param [String] identifier A unique identifier to generate the temporary file path
  # @return [[String]] Array of image_paths
  def pdf_to_image(path, identifier)
    pdf = MiniMagick::Image.open(path)
    image_paths = []

    pdf.pages.each_with_index do |page, index|
      output_path = Rails.root.join('tmp', "#{identifier}_#{index}.jpg")
      MiniMagick::Tool::Convert.new do |convert|
        convert.background 'white'
        convert.flatten
        convert.density 100
        convert.quality 50
        convert << page.path
        convert << output_path
      end
      image_paths << output_path
    end

    image_paths
  end
end
