# frozen_string_literal: true
module Common
  module Serializer
    def date_attr(*names, override_name: nil)
      name = override_name || names.last
      define_method(name) do
        date = object_data.dig(*names)
        return unless date
        Date.strptime(date, '%m/%d/%Y')
      end
    end

    def yes_no_attr(*names, override_name: nil)
      name = override_name || names.last
      define_method(name) do
        s = object_data.dig(*names)
        return unless s
        case s.downcase
        when 'yes' then true
        when 'no' then false
        else
          Rails.logger.error "Expected key '#{keys}' to be Yes/No. Got '#{s}'."
          nil
        end
      end
    end
  end
end
