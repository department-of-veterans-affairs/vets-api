# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Search
      module Query
        module Page
          module Size
            # For the moment, these values duplicate the behavior of BGS.
            DEFAULT = 25
            MAX = 100
            MIN = 1
          end
        end

        module Sort
          module Fields
            ALL = [
              CREATED_AT = 'createdAt'
            ].freeze
          end

          module Orders
            ALL = [
              ASCENDING = 'asc',
              DESCENDING = 'desc'
            ].freeze
          end

          class << self
            # These only make sense as defaults together. Also it seems sensible
            # to not return the same hash instance when using these sort param
            # defaults which is why this is a method.
            def get_default
              {
                field: Fields::CREATED_AT,
                order: Orders::DESCENDING
              }
            end
          end
        end

        # TODO: If keeping `dry-schema`, consider a good point to load
        # extensions.
        #
        # These have to load before our `Schema` definition, otherwise at least
        # the `hints` extension won't do its thing.
        Dry::Schema.load_extensions(:json_schema)
        Dry::Schema.load_extensions(:hints)

        Schema =
          # See https://dry-rb.org/gems/dry-schema
          Dry::Schema.Params do
            required(:filter).hash do
              required(:poaCodes).filled(:array).each(:string)
              optional(:statuses).filled(:array).each(
                :string, included_in?: PoaRequest::Decision::Statuses::ALL
              )
            end

            optional(:page).hash do
              optional(:number).value(:integer, gteq?: 1)
              optional(:size).value(
                :integer, gteq?: Page::Size::MIN, lteq?: Page::Size::MAX
              )
            end

            optional(:sort).hash do
              # If the client is going to send one of these, it only really
              # makes sense to send both, because otherwise it's an
              # exceptionally weird query for them to make.
              required(:field).value(:string, included_in?: Sort::Fields::ALL)
              required(:order).value(:string, included_in?: Sort::Orders::ALL)
            end
          end

        class << self
          def compile!(params)
            result = Schema.call(params)

            if result.failure?
              raise InvalidQueryError.new(
                result.messages.to_h,
                params
              )
            end

            result.to_h.tap do |query|
              apply_defaults(query)
            end
          end

          private

          def apply_defaults(query)
            query[:filter][:statuses] ||= PoaRequest::Decision::Statuses::ALL
            query[:sort] ||= Sort.get_default

            page = query[:page] ||= {}
            page[:size] ||= Page::Size::DEFAULT
            page[:number] ||= 1
          end
        end
      end
    end
  end
end
