# frozen_string_literal: true

module Mobile
  class ListFilter
    def initialize(collection, filters)
      @collection = collection
      @filters = filters
    end

    # Accepts params:
    #   @collection - a Common::Collection of Common::Base models
    #   @filters - should be an ActionController::Parameters object which should be passed in from the
    #     controller via @params[:filter]. This will pass in another ActionController::Parameters object.
    # Returns: a new Common::Collection of Common::Base models that match the provided filters
    def self.matches(collection, filters)
      filterer = new(collection, filters)
      filterer.result
    end

    # carrying over errors and metadata while merging filters into metadata because
    # that's how the Common::Collection filter works. these values are probably not used again
    def result
      metadata = @collection.metadata.merge(filter: @filters)
      Common::Collection.new(data: matches, metadata: metadata, errors: @collection.errors)
    end

    private

    def matches
      @collection.data.select { |record| matches_filters?(record) }
    end

    # to_unsafe_hash sounds dangerous, but it is not unsafe for our purposes.
    # as part of the strong params pattern, only params that have been explicitly
    # permitted are included in the results of .to_h to avoid them being included
    # in mass assignment when creating new models like Model.create(params).
    # we are not using the Parameters object for mass assignment, so we do not need
    # a sanitized version of the hash
    def matches_filters?(record)
      @filters.to_unsafe_hash.all? do |match_attribute, remainder|
        # we will need to validate that there is only one pair.
        # it's possible we could design more complex cases where there are multiple pairs
        operation = remainder.keys.first
        value = remainder.values.first

        case operation.to_sym
        when :eq
          record[match_attribute.to_sym] == value
        when :notEq
          record[match_attribute.to_sym] != value
        end
      end
    end
  end
end
