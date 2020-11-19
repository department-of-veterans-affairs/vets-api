# frozen_string_literal: true

module Ask
  module Iris
    module Oracle
      class TextAreaField
        def self.set_value(browser, field_name, value)
          browser.set_text_area(field_name, value)
        end
      end
    end
  end
end
