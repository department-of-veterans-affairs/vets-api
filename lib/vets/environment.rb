# frozen_string_literal: true

# .to_s and .inspect are required to output a string
# and still work with the predicate methods
module Vets
  # Vets::Environment provides methods to get and check the
  # current vsp_environment similar to Rails.env.
  class Environment
    class << self
      def current
        ENV['VSP_ENVIRONMENT'] || 'localhost'
      end

      def to_s
        current
      end

      delegate :inspect, to: :current

      def development?
        current == 'development'
      end

      def production?
        current == 'production'
      end

      def staging?
        current == 'staging'
      end

      def sandbox?
        current == 'sandbox'
      end

      def local?
        test? || localhost?
      end

      def lower?
        development? || staging?
      end

      def higher?
        sandbox? || production?
      end

      def deployed?
        !local?
      end

      private

      def test?
        current == 'test'
      end

      def localhost?
        current == 'localhost'
      end
    end
  end

  # Vets.env allows you to access the Env class and call its methods.
  # Example usage:
  #   Vets.env              # => "development" (or "production", etc.)
  #   Vets.env.to_s         # => "development"
  #   Vets.env.production?  # => false (if not in production)
  #   Vets.env.development? # => true (if in development)
  def self.env
    Environment
  end
end
