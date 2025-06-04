# frozen_string_literal: true

module IncomeAndAssets
  # Individual section of the form to be filled
  class Section
    include ::PdfFill::Forms::FormHelper
    include IncomeAndAssets::Helpers

    # Hash iterator
    ITERATOR = ::PdfFill::HashConverter::ITERATOR

    # Form configuration hash
    KEY = {}.freeze

    ##
    # Expands individual section by processing each entry in the section and
    # in some cases setting an indicator for the presense of entries for the section
    #
    # @abstract
    #
    # @param form_data [Hash]
    #
    # @note May modify `form_data`
    #
    def expand(form_data)
      raise NotImplementedError, 'Class must implement expand method'
    end

    ##
    # Expands an individual items data by processing its attributes and transforming them into
    # structured output
    #
    # @abstract
    #
    # @param item [Hash]
    # @return [Hash]
    #
    def expand_item(item)
      raise NotImplementedError, 'Class must implement expand_item method'
    end

    ##
    # Generates a key for the form field based on the subprefix and key
    #
    # @param subprefix [String] the subprefix identifier
    # @param key [String] the specific key within the subsection
    # @return [String] the generated key for the form field
    #
    def self.generate_key(subprefix, key)
      "#{key_prefix}#{subprefix}.#{key}"
    end

    ##
    # Prefix for form field keys - can be redefined by subclasses as needed
    #
    def self.key_prefix
      name.split('::').last
    end
  end
end
