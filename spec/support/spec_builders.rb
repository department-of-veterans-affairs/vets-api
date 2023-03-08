# frozen_string_literal: true

require 'active_support/concern'

module SpecBuilders
  extend ActiveSupport::Concern

  module ClassMethods
    def test_method(klass, method, test_data)
      describe "##{method}" do
        test_data.each do |test_datum|
          args = Array.wrap(test_datum[0])
          return_val = test_datum[1]

          context "with an input of #{args.join(',')}" do
            it "returns #{return_val}" do
              actual =
                if args.length == 1 && args[0].is_a?(Hash) && !args[0].empty?
                  klass.send(method, **args.first)
                else
                  klass.send(method, *args)
                end

              expect(actual).to eq(return_val)
            end
          end
        end
      end
    end
  end
end
