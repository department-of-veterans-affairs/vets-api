# frozen_string_literal: true

require 'concurrent'
require_relative 'constants'

module VcrMcp
  # Service configuration and detection for VCR cassettes
  # Dynamically parses spec/support/vcr.rb to extract placeholder-to-settings mappings
  class ServiceConfig
    # Port range for auto-assignment (4480-4499)
    PORT_RANGE_START = 4480
    PORT_RANGE_END = 4499

    # Path to VCR configuration file (source of truth for placeholder mappings)
    VCR_CONFIG_PATH = File.join(Constants::VETS_API_ROOT, 'spec', 'support', 'vcr.rb')

    # Services that can be accessed directly (no tunnel needed)
    DIRECT_ACCESS_NAMESPACES = %w[lighthouse].freeze

    # Thread-safe cache storage using Concurrent::Map
    CACHE = Concurrent::Map.new

    class << self
      # Parse vcr.rb to extract placeholder -> Settings path mappings
      # Returns hash like: { 'MHV_UHD_HOST' => 'mhv.uhd.host', 'MHV_SM_HOST' => 'mhv.api_gateway.hosts.sm_patient' }
      def parse_vcr_placeholders
        cached_fetch(:vcr_placeholders) { load_placeholders_from_config }
      end

      def load_placeholders_from_config
        return {} unless File.exist?(VCR_CONFIG_PATH)

        content = File.read(VCR_CONFIG_PATH)
        extract_placeholders_from_content(content)
      end

      def extract_placeholders_from_content(content)
        placeholders = {}
        pattern = /filter_sensitive_data\(['"]<([^>]+)>['"]\)\s*(?:\{\s*([^}]+)\s*\}|do\s*\n?\s*([^e]+?)\s*end)/m

        content.scan(pattern) do |match|
          placeholder_name = match[0]
          settings_expr = (match[1] || match[2])&.strip

          next unless settings_expr&.start_with?('Settings.')

          settings_path = settings_expr.sub(/^Settings\./, '').strip
          placeholders[placeholder_name] = settings_path
        end

        placeholders
      end

      # Derive settings namespace from a full settings path
      # e.g., 'mhv.uhd.host' -> 'mhv.uhd', 'mhv.uhd.security_host' -> 'mhv.uhd'
      def settings_namespace_from_path(settings_path)
        parts = settings_path.split('.')
        return settings_path if parts.length < 2
        return derive_namespace_from_special_path(parts) if parts[-2] == 'hosts'

        parts[0..-2].join('.')
      end

      # Handle special path patterns
      def derive_namespace_from_special_path(parts)
        # mhv.api_gateway.hosts.sm_patient -> mhv.sm
        return 'mhv.sm' if parts.include?('api_gateway') &&
                           parts.include?('hosts') &&
                           parts.last.include?('sm')

        parts[0..-2].join('.')
      end

      # Build a mapping of placeholder names to their settings namespaces
      # Note: Fetches placeholders first to avoid recursive locking in cached_fetch
      def placeholder_to_namespace
        # Fetch placeholders outside the cache block to avoid deadlock
        placeholders = parse_vcr_placeholders
        cached_fetch(:placeholder_to_namespace) { build_placeholder_to_namespace_mapping(placeholders) }
      end

      def build_placeholder_to_namespace_mapping(placeholders)
        mapping = {}
        placeholders.each do |placeholder, settings_path|
          namespace = settings_namespace_from_path(settings_path)
          mapping[placeholder] = namespace
        end
        mapping
      end

      # Group placeholders by their settings namespace
      # Note: Fetches placeholder_to_namespace first to avoid recursive locking
      def namespaces_to_placeholders
        # Fetch mapping outside the cache block to avoid deadlock
        mapping = placeholder_to_namespace
        cached_fetch(:namespaces_to_placeholders) { build_namespaces_to_placeholders_mapping(mapping) }
      end

      def build_namespaces_to_placeholders_mapping(mapping)
        grouped = Hash.new { |h, k| h[k] = [] }
        mapping.each do |placeholder, namespace|
          grouped[namespace] << placeholder
        end
        grouped
      end

      def detect_from_cassette(_cassette_path, interactions = [])
        # Detect service based on VCR placeholder names found in cassette URIs
        # Uses vcr.rb as the source of truth
        detect_by_placeholders(interactions)
      end

      # Detects service based on VCR placeholder names in URIs
      # Dynamically reads from spec/support/vcr.rb
      def detect_by_placeholders(interactions)
        # rubocop:disable Rails/Blank
        return nil if interactions.nil? || interactions.empty?
        # rubocop:enable Rails/Blank

        uris = interactions.map { |i| i.dig(:request, :uri) }.compact
        return nil if uris.empty?

        # Check each placeholder from vcr.rb
        placeholder_to_namespace.each do |placeholder, namespace|
          # Match placeholders like <MHV_UHD_HOST> in URIs
          pattern = /<#{Regexp.escape(placeholder)}>/
          return build_service_result(namespace, placeholder) if uris.any? { |uri| uri.match?(pattern) }
        end

        nil
      end

      def build_service_result(namespace, detected_placeholder = nil)
        return nil unless namespace

        placeholders = namespaces_to_placeholders[namespace] || []
        connection_method = DIRECT_ACCESS_NAMESPACES.include?(namespace) ? :direct : :forward_proxy

        {
          key: namespace.tr('.', '_'),
          name: humanize_namespace(namespace),
          settings_namespace: namespace,
          connection_method:,
          placeholders:,
          detected_placeholder:,
          local_port: assign_port(namespace)
        }
      end

      # Convert namespace to human-readable name
      # e.g., 'mhv.uhd' -> 'MHV UHD', 'mhv.sm' -> 'MHV SM'
      def humanize_namespace(namespace)
        namespace
          .split('.')
          .map { |part| part.gsub('_', ' ').upcase }
          .join(' ')
      end

      def assign_port(identifier)
        hash = identifier.to_s.bytes.sum
        PORT_RANGE_START + (hash % (PORT_RANGE_END - PORT_RANGE_START + 1))
      end

      def aws_region
        Constants::AWS_REGION
      end

      # List all known placeholders from vcr.rb
      def all_placeholders
        parse_vcr_placeholders
      end

      # List all detected namespaces
      def all_namespaces
        namespaces_to_placeholders.keys
      end

      # Clear cached data (useful for testing or after vcr.rb changes)
      def reset_cache!
        CACHE.clear
      end

      private

      def cached_fetch(key, &)
        CACHE.compute_if_absent(key, &)
      end
    end
  end
end
