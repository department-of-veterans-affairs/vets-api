# frozen_string_literal: true

module AuditLogger
  module Storage
    class BaseAdapter
      def client
        raise NotImplementedError, 'client method must be implemented'
      end

      def write(log)
        raise NotImplementedError, 'write method must be implemented'
      end

      def read(query)
        raise NotImplementedError, 'read method must be implemented'
      end

      def validate!
        raise NotImplementedError, 'validate! method must be implemented'
      end

      def inspect
        "#<#{self.class.name}>"
      end
    end
  end
end
