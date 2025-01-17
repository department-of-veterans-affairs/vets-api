# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Search
      module Query
        # TODO: If keeping `dry-schema`, consider a good point to load these
        # extensions. The `hints` extension has to load before our `Schema`
        # definition, otherwise it won't do its thing. And that may be true for
        # the `json_schema` extension too.
        Dry::Schema.load_extensions(:json_schema)
        Dry::Schema.load_extensions(:hints)

        Schema =
          # See https://dry-rb.org/gems/dry-schema
          Dry::Schema.Params do
            required(:filter).hash do
              required(:poaCodes).filled(:array).each(:string, :filled?)
              optional(:decision).hash do
                optional(:statuses).filled(:array).each(
                  :string, included_in?: Filter::Decision::Statuses::ALL
                )
              end
            end

            optional(:page).hash do
              optional(:number).value(:integer, gteq?: 1)
              optional(:size).value(
                :integer,
                gteq?: Page::Size::MIN,
                lteq?: Page::Size::MAX
              )
            end

            optional(:sort).hash do
              # If the client is going to send one of these, it only really
              # makes sense to send both, because otherwise it's kind of a
              # nonsensical query for them to make.
              required(:field).value(:string, included_in?: Sort::Fields::ALL)
              required(:order).value(:string, included_in?: Sort::Orders::ALL)
            end
          end

        class << self
          def compile!(params)
            result = Schema.call(params)
            result.success? or raise(
              ::Common::Exceptions::SchemaValidationErrors,
              [{ errors: result.messages.to_h, params: }]
            )

            result.to_h.tap do |query|
              apply_defaults(query)
            end
          end

          private

          def apply_defaults(query)
            query[:filter][:decision] ||= {}
            query[:filter][:decision][:statuses] ||=
              Filter::Decision::Statuses::ALL

            query[:sort] ||= {
              # These only make sense as defaults together.
              field: Sort::Fields::CREATED_AT,
              order: Sort::Orders::DESCENDING
            }

            page = query[:page] ||= {}
            page[:size] ||= Page::Size::DEFAULT
            page[:number] ||= 1
          end
        end
      end
    end
  end
end
