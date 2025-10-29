# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section VI: Marital Status
    class Section6 < Section
      # Section configuration hash
      KEY = {}.freeze

      def expand(form_data)
        # Add expansion logic here
      end
    end
  end
end
