# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ApplicationSerializer
    include JSONAPI::Serializer

    # We're not building to JSONAPI.
    def serializable_hash
      data = super[:data]

      case data
      when Array
        data.map(&method(:unwrap_serializable_hash))
      when Hash
        unwrap_serializable_hash(data)
      end
    end

    private

    def unwrap_serializable_hash(data)
      data[:attributes].merge!(id: data[:id])
    end
  end
end
