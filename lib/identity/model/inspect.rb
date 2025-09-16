# frozen_string_literal: true

module Identity
  module Model
    module Inspect
      def inspect
        return super unless respond_to?(:attribute_names)

        inspection = attribute_names.map do |name|
          "#{name}: #{public_send(name).inspect}"
        end.join(', ')

        "#<#{self.class} #{inspection}>"
      end

      def pretty_print(pp)
        return super unless respond_to?(:attributes)

        names = attributes.keys.sort

        pp.object_address_group(self) do
          pp.seplist(names, proc { pp.text ',' }) do |name|
            val = attributes[name]
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
end
