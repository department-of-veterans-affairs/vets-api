# frozen_string_literal: true

module DependentsVerification
  # Individual section of the form to be filled
  class Section
    include ::PdfFill::Forms::FormHelper

    # Hash iterator
    ITERATOR = ::PdfFill::HashConverter::ITERATOR

    # Form configuration hash
    KEY = {}.freeze

    ##
    # Generates a unique key name based on the class name and provided parameters.
    #
    # @param params [Array<String>] The parameters to include in the key name
    # @return [String] The generated key name, ex: 'Section1.1.VeteransName.First'
    def self.key_name(*params)
      "#{name.split('::').last}.#{params.join('.')}"
    end
  end
end
