# frozen_string_literal: true

module PdfFillHelper
  # Given two paths to (non-flattened) PDFs this will return true
  # if the PDFs have the same values for every field.
  # def pdfs_fields_match?(pdf_1_path, pdf_2_path)
  #   fields = []
  #   [pdf_1_path, pdf_2_path].each do |pdf|
  #     fields << simplify_fields(
  #       pdf_forms.get_fields(pdf)
  #     )
  #   end

  #   fields[0] == fields[1]
  # end
  def pdfs_fields_match?(pdf_1_path, pdf_2_path)
    fields = []
    [pdf_1_path, pdf_2_path].each do |pdf|
      fields << simplify_fields(pdf_forms.get_fields(pdf))
    end
  
    mismatches = []
    fields[0].each do |field_1|
      matching_field = fields[1].find { |field_2| field_2[:name] == field_1[:name] }
      
      if matching_field.nil?
        mismatches << "Field missing in PDF 2: #{field_1[:name]} (Value: #{field_1[:value]})"
      elsif field_1[:value] != matching_field[:value]
        mismatches << "Field '#{field_1[:name]}' mismatch: temp PDF = '#{field_1[:value]}', test PDF = '#{matching_field[:value]}'"
      end
    end
  
    fields[1].each do |field_2|
      unless fields[0].any? { |field_1| field_1[:name] == field_2[:name] }
        mismatches << "Field missing in PDF 1: #{field_2[:name]} (Value: #{field_2[:value]})"
      end
    end
  
    unless mismatches.empty?
      puts "PDF Field Mismatches:"
      mismatches.each { |m| puts m }
    end
  
    mismatches.empty?
  end
  
  

  private

  def pdf_forms
    PdfForms.new(Settings.binaries.pdftk)
  end

  def simplify_fields(fields)
    fields.map do |field|
      {
        name: field.name,
        value: field.value
      }
    end
  end
end
