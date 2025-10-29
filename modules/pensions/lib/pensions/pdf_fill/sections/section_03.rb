# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section III: Veteran Service Information
    class Section3 < Section
      # Section configuration hash
      KEY = {}.freeze

      def expand(form_data)
        # Add expansion logic here
      end
    end
  end
end
