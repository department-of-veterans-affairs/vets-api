# frozen_string_literal: true

module Ask
  module Iris
    module Oracle
      module FieldTypes
        class OracleCustomDropdownField
          def self.set_value(browser, field_name, value)
            return if value.nil?

            browser.click_button_by_id(field_name)
            browser.click_link(value)
          end
        end
      end
    end
  end
end
