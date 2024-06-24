# frozen_string_literal: true

module FastJsonapi
  module SerializationCore
    class_methods do
      def id_hash(id, record_type, default_return = false)
        if id.present?
          { id: id.to_s, type: record_type }
        else
          default_return ? { id: '', type: record_type } : nil
        end
      end
    end
  end
end
