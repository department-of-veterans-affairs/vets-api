module Ask
    module Iris
        module Oracle
          class DropdownField
              def self.set_value(browser, field_name, value)
                return if value.nil?
                browser.select_dropdown_by_text(field_name, value)
              end
          end
        end
    end
end

