# frozen_string_literal: true

require 'income_and_assets/engine'

# The IncomeAndAssets module serves as a namespace for all classes, methods, and constants
# related to the Income and Assets functionality. It encapsulates all logic relevant to
# handling income and asset data.
module IncomeAndAssets
  # Income and Assets Form ID
  FORM_ID = '21P-0969'

  # The module path
  MODULE_PATH = 'modules/income_and_assets'

  # API Version 0
  module V0
  end

  # PdfFill
  # @see lib/pdf_fill
  module PdfFill
  end
end
