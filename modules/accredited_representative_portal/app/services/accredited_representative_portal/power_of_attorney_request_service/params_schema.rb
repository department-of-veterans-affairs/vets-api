# frozen_string_literal: true

module AccreditedRepresentativePortal
  module PowerOfAttorneyRequestService
    module ParamsSchema
      # Load extensions needed for schema validation
      Dry::Schema.load_extensions(:json_schema)
      Dry::Schema.load_extensions(:hints)

      module Page
        module Size
          MIN = 10
          MAX = 100
          DEFAULT = 10
        end
      end

      module Sort
        ALLOWED_FIELDS = %w[created_at].freeze
        ALLOWED_ORDERS = %w[asc desc].freeze
        DEFAULT_ORDER = 'desc'
      end

      module Statuses
        ALL = [
          PENDING = 'pending',
          PROCESSED = 'processed'
        ].freeze
      end

      Schema = Dry::Schema.Params do
        optional(:page).hash do
          optional(:number).value(:integer, gteq?: 1)
          optional(:size).value(
            :integer,
            gteq?: Page::Size::MIN,
            lteq?: Page::Size::MAX
          )
        end

        optional(:sort).hash do
          optional(:by).value(:string, included_in?: Sort::ALLOWED_FIELDS)
          optional(:order).value(:string, included_in?: Sort::ALLOWED_ORDERS)
        end

        optional(:status).value(:string, included_in?: Statuses::ALL)
      end

      class << self
        def validate_and_normalize!(params)
          result = Schema.call(params)
          result.success? or raise(
            ActionController::BadRequest,
            "Invalid parameters: #{result.errors.messages}"
          )

          result.to_h.tap do |validated_params|
            apply_defaults(validated_params)
          end
        end

        private

        def apply_defaults(validated_params)
          validated_params[:page] ||= {}
          validated_params[:page][:number] ||= 1
          validated_params[:page][:size] ||= Page::Size::DEFAULT

          if validated_params[:sort].present? && validated_params[:sort][:by].present?
            validated_params[:sort][:order] ||= Sort::DEFAULT_ORDER
          end
        end
      end
    end
  end
end
