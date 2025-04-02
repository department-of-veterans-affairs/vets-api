# frozen_string_literal: true

require 'combine_pdf/api'

# Suppresses CombinePDF warning "Couldn't connect reference for" and "Form data might be lost"
# more info: https://github.com/department-of-veterans-affairs/vets-api/pull/16705

Rails.application.config.after_initialize do
  if Rails.env.test?
    CombinePDF::PDFParser.prepend(Module.new do
      def warn(*msgs, **)
        msgs.reject! { |msg| msg.start_with?("Couldn't connect reference for") }
        super
      end
    end)

    CombinePDF::PDF.prepend(Module.new do
      def warn(*msgs, **)
        msgs.reject! { |msg| msg.start_with?('Form data might be lost') }
        super
      end
    end)
  end
end
