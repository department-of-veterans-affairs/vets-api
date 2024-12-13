# frozen_string_literal: true

#
# A Vets::Collection allows array of Vets::Model models to be
# sorted, filtered, or paginated.
#

require 'common/models/comparable/ascending'
require 'common/models/comparable/descending'

module Vets
  class Collection
    def initialize(records)
      records = Array.wrap(records)
      @model_class = records.first.class

      unless records.all? { |record| record.is_a?(@model_class) }
        raise ArgumentError, "All records must be instances of #{@model_class}"
      end

      @records = records.sort
    end

    def self.from_hashes(model_class, records)
      raise ArgumentError, 'Expected an array of hashes' unless records.all? { |r| r.is_a?(Hash) }

      records = records.map { |record| model_class.new(**record) }
      new(records)
    end

    def order(clauses = {})
      validate_sort_clauses(clauses)

      @records.sort_by do |record|
        clauses.map do |attribute, direction|
          value = record.public_send(attribute)
          direction == :asc ? Common::Ascending.new(value) : Common::Descending.new(value)
        end
      end
    end

    private

    def validate_sort_clauses(clauses)
      raise ArgumentError, "Order must have at least one sort clause" if clauses.empty?

      clauses.each do |attribute, direction|
        raise ArgumentError, "Attribute #{attribute} must be a symbol" unless attribute.is_a?(Symbol)

        unless @records.first.respond_to?(attribute)
          raise ArgumentError, "Attribute #{attribute} does not exist on the model"
        end

        raise ArgumentError, "Direction #{direction} must be :asc or :desc" unless %i[asc desc].include?(direction)
      end
    end
  end
end
