module PdfFill
  module Forms
    class FormBase
      def self.date_strftime
        '%m/%d/%Y'
      end

      def initialize(form_data)
        @form_data = form_data.deep_dup
      end
    end
  end
end
