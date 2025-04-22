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
  end

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
end
