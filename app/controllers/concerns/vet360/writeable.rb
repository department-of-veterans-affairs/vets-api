# frozen_string_literal: true

module Vet360
  module Writeable
    extend ActiveSupport::Concern

    # For the passed Vet360 model type and params, it:
    #   - builds and validates a Vet360 models
    #   - POSTs/PUTs the model data to Vet360
    #   - creates a new AsyncTransaction db record, based on the type
    #   - renders the transaction through the base serializer
    #
    # @param type [String] the Vet360::Models type (i.e. 'Email', 'Address', etc.)
    # @param params [ActionController::Parameters ] The strong params from the controller
    # @param http_verb [String] The type of write request being made to Vet360 ('post' or 'put')
    # @return [Response] Normal controller `render json:` response with a response.body, .status, etc.
    #
    def write_to_vet360_and_render_transaction!(type, params, http_verb: 'post')
      record = build_record(type, params)
      validate!(record)
      response = write_valid_record!(http_verb, type, record)
      render_new_transaction!(type, response)
    end

    private

    def build_record(type, params)
      "Vet360::Models::#{type.capitalize}"
        .constantize
        .new(params)
        .set_defaults(@current_user)
    end

    def validate!(record)
      raise Common::Exceptions::ValidationErrors, record unless record.valid?
    end

    def service
      Vet360::ContactInformation::Service.new @current_user
    end

    def write_valid_record!(http_verb, type, record)
      service.send("#{http_verb}_#{type.downcase}", record)
    end

    def render_new_transaction!(type, response)
      transaction = "AsyncTransaction::Vet360::#{type.capitalize}Transaction".constantize.start(@current_user, response)

      render json: transaction, serializer: AsyncTransaction::BaseSerializer
    end
  end
end
