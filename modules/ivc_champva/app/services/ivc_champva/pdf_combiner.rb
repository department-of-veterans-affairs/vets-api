# frozen_string_literal: true

module IvcChampva
  class PdfCombiner
    # Generic utility to combine multiple PDFs into a single PDF, maintaining
    # the order of the original files

    # @param merged_pdf_path [String] The path of the output file
    # @param file_paths [Array<String>] The paths to the PDFs to combine
    # @return [String] The path to the combined PDF
    def self.combine(merged_pdf_path, file_paths)
      return merged_pdf_path if file_paths.empty?

      combined_pdf = CombinePDF.new

      file_paths.each do |file_path|
        pdf = CombinePDF.load(file_path)
        pdf.pages.each do |page|
          # Store the source filename directly in the page hash
          # this will not be visible in the final PDF
          page[:SourceFileName] = file_path
        end
        combined_pdf << pdf
      rescue => e
        Rails.logger.error("Error merging #{file_path}: #{e.message}")
        raise
      end

      combined_pdf.save merged_pdf_path
      merged_pdf_path
    end
  end
end
