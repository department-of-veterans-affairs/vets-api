#!/usr/bin/env ruby
# frozen_string_literal: true

# 1. Minimal ActiveSupport shims
class Object
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end

  def present?
    !blank?
  end

  def deep_dup
    if is_a?(Hash)
      transform_values { |v| v.deep_dup }
    elsif is_a?(Array)
      map { |v| v.deep_dup }
    else
      dup rescue self
    end
  end
end

class NilClass
  def blank?
    true
  end
end

class Array
  def compact_blank
    reject(&:blank?)
  end
end

class String
  def blank?
    strip.empty?
  end
end

class Module
  def delegate(*methods, to: nil)
    methods.each do |method_name|
      define_method(method_name) do |*args, &block|
        target = to.to_s.start_with?('@') ? instance_variable_get(to) : send(to)
        target.send(method_name, *args, &block)
      end
    end
  end
end


# 2. Mock PdfFill::FormValue
module PdfFill
  class FormValue
    attr_reader :value, :extras

    def initialize(value, extras)
      @value = value
      @extras = extras
    end

    def to_s
      @value.to_s
    end
  end
  
  # Mock HashConverter::ITERATOR
  module HashConverter
    ITERATOR = '%iterator%'
  end
end

# 3. Load the Form Classes
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

# We need to manually require the dependencies since we aren't using autoload/bundler
require 'date'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/va2210278'

# 4. Implement Minimal Filler using system pdftk
class MinimalFiller
  def self.fill(payload, form_class, input_pdf, output_pdf)
    # 1. Process Data
    form_instance = form_class.new(payload)
    merged_data = form_instance.merge_fields

    # 2. Map to FDF key-values
    fdf_data = {}
    
    # Iterate through keys defined in the class
    process_keys(form_class::KEY, merged_data, fdf_data)

    # 3. Generate FDF file
    fdf_path = output_pdf.gsub('.pdf', '.fdf')
    generate_fdf(fdf_data, fdf_path)

    # 4. Run pdftk
    system("pdftk #{input_pdf} fill_form #{fdf_path} output #{output_pdf}")
    
    # Cleanup
    File.unlink(fdf_path) if File.exist?(fdf_path)
  end

  def self.process_keys(key_map, data, result)
    key_map.each do |data_key, config|
      value = data[data_key]
      next if value.nil?

      if config.is_a?(Hash) && config[:iterator]
        # Array with iterator
        iterator_placeholder = config[:iterator]
        pdf_key_template = config[:key]
        
        if value.is_a?(Array)
          value.each_with_index do |item, index|
            # Replace placeholder with index
            pdf_key = pdf_key_template.sub(iterator_placeholder, index.to_s)
            result[pdf_key] = item
          end
        end
      elsif config.is_a?(Hash) && config[:key]
        # Leaf node
        pdf_field = config[:key]
        result[pdf_field] = value
      elsif value.is_a?(Hash)
        process_keys(config, value, result)
      end
    end
    
    # Also handle keys that were flattened/added in merge_fields but aren't in the nested structure anymore
    # The merge_fields method in Va2210278 modifies @form_data directly.
    # For example, organizationRepresentatives mapped to organizationRepresentatives0..5
    # These new keys are not in the KEY constant structure in the same way.
    # So we should also look at the data itself.
    
    data.each do |k, v|
      if k == 'ssn2' || k == 'ssn3'
        result[k] = v
      elsif k == 'isLimited' || k == 'isNotLimited'
        result[k] = v
      elsif k == 'lengthOfRelease'
        # keys like isOngoing, isDated, releaseDate are inside lengthOfRelease hash
         if v.is_a?(Hash)
           v.each do |sub_k, sub_v|
             result[sub_k] = sub_v if sub_v
           end
         end
      elsif k == 'securityQuestion'
         # question is inside
         result['question'] = v['question'] if v.is_a?(Hash)
      elsif k == 'securityAnswer'
         # answer is inside
         result['answer'] = v['answer'] if v.is_a?(Hash)
      elsif k == 'statementOfTruthSignature'
        result['statementOfTruthSignature'] = v
      elsif k == 'dateSigned'
        result['dateSigned'] = v
      end
    end
  end

  def self.generate_fdf(data, path)
    # Simple FDF generation
    header = "%FDF-1.2\n1 0 obj\n<< /FDF << /Fields [\n"
    footer = "] >> >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n"
    
    fields = data.map do |key, value|
      value = '' if value.nil?
      value = value.to_s.gsub('(', '\(').gsub(')', '\)')
      "<< /T (#{key}) /V (#{value}) >>"
    end.join("\n")

    File.write(path, header + fields + footer)
  end
end

# Payload
payload = {
  'claimantPersonalInformation' => {
    'fullName' => {
      'first' => 'John',
      'middle' => 'Quincy',
      'last' => 'Doe'
    },
    'ssn' => '123-45-6789',
    'vaFileNumber' => '987654321',
    'dateOfBirth' => '1980-01-01'
  },
  'claimantAddress' => {
    'addressLine1' => '123 Main St',
    'city' => 'Anytown',
    'stateCode' => 'NY',
    'zipCode' => '12345',
    'countryName' => 'USA'
  },
  'claimantContactInformation' => {
    'phoneNumber' => '5551234567',
    'emailAddress' => 'john.doe@example.com'
  },
  'thirdPartyPersonName' => {
    'first' => 'Jane',
    'last' => 'Smith'
  },
  'thirdPartyPersonAddress' => {
    'street' => '456 Elm St',
    'city' => 'Othertown',
    'state' => 'CA',
    'postalCode' => '90210',
    'country' => 'USA'
  },
  'thirdPartyOrganizationInformation' => {
    'organizationName' => 'Veterans Aid Org',
    'organizationAddress' => {
      'street' => '789 Oak Ave',
      'city' => 'Big City',
      'state' => 'TX',
      'postalCode' => '75001',
      'country' => 'USA'
    }
  },
  'organizationRepresentatives' => [
    { 'fullName' => { 'first' => 'Rep', 'last' => 'One' } },
    { 'fullName' => { 'first' => 'Rep', 'last' => 'Two' } }
  ],
  'claimInformation' => {
    'statusOfClaim' => true,
    'other' => true,
    'otherText' => 'Custom Claim Info'
  },
  'lengthOfRelease' => {
    'lengthOfRelease' => 'date',
    'date' => '2025-12-31'
  },
  'securityQuestion' => {
    'question' => 'create'
  },
  'securityAnswer' => {
    'securityAnswerCreate' => {
      'question' => 'What is your favorite color?',
      'answer' => 'Blue'
    }
  },
  'statementOfTruthSignature' => 'John Q Doe',
  'dateSigned' => '2023-10-27'
}

input_pdf = 'lib/pdf_fill/forms/pdfs/22-10278.pdf'
output_pdf = 'tmp/test_22-10278.pdf'

puts "Generating PDF..."
MinimalFiller.fill(payload, PdfFill::Forms::Va2210278, input_pdf, output_pdf)
puts "Done: #{output_pdf}"
