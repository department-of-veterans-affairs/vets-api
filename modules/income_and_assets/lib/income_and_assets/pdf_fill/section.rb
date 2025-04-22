# frozen_string_literal: true

module IncomeAndAssets
  class Section
    include ::PdfFill::Forms::FormHelper
    include IncomeAndAssets::Helpers

    # Hash iterator
    ITERATOR = ::PdfFill::HashConverter::ITERATOR

    KEY = {}.freeze
  end

  def expand
    raise NotImplementedError, 'Class must implement expand method'
  end

  def expand_item
    raise NotImplementedError, 'Class must implement expand_item method'
  end
end
