# frozen_string_literal: true

module AsyncTransaction
  class BaseSerializer
    include JSONAPI::Serializer

    set_id { '' }

    attribute :transaction_id
    attribute :transaction_status
    attribute :type
    attribute :metadata, &:parsed_metadata

    # This is needed to set the correct type based on the object(s) being serialized
    def serializable_hash
      hash = super
      if hash[:data].is_a?(Array)
        hash[:data].each_with_index { |h, i| h[:type] = @resource[i].class.name.underscore.gsub('/', '_').pluralize }
      else
        hash[:data][:type] = @resource.class.name.underscore.gsub('/', '_').pluralize
      end
      hash
    end
  end
end
