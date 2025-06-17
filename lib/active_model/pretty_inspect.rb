# frozen_string_literal: true

module ActiveModel
  module PrettyInspect
    # Based on ActiveRecord::Core#inspect
    def inspect
      return super unless defined?(attributes)

      attrs_inspection = attributes.map { |name, val| "#{name}: #{val.inspect}" }.join(', ')

      "#<#{self.class}:0x#{object_id.to_s(16)} #{attrs_inspection}>"
    end

    # Based on ActiveRecord::Core#pretty_print
    def pretty_print(pp)
      return super unless defined?(attributes)

      attrs = attributes.names.sort

      pp.object_address_group(self) do
        pp.seplist(attrs, proc { pp.text ',' }) do |name|
          val = attrs[name].value
          pp.breakable ' '
          pp.group(1) do
            pp.text name
            pp.text ':'
            pp.breakable
            pp.pp val
          end
        end
      end
    end
  end
end
