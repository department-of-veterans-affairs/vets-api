# frozen_string_literal: true

module Ask
  module Iris
    module Oracle
      module FieldTypes
        class TextField
          def self.set_value(browser, field_name, value)
            browser.set_text_field(field_name, value)
          end
        end
      end
    end
  end
end
