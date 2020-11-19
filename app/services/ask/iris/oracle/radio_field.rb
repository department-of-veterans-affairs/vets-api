module Ask
    module Iris
        module Oracle
            class RadioField
                def self.set_value(browser, field_name, value)
                  browser.set_yes_no_radio(field_name, value)
                end
            end
        end
    end
end