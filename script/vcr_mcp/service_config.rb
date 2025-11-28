# frozen_string_literal: true

module VcrMcp
  # Service configuration and detection for VCR cassettes
  # Dynamically parses spec/support/vcr.rb to extract placeholder-to-settings mappings
  class ServiceConfig
    # Port range for auto-assignment (4480-4499)
    PORT_RANGE_START = 4480
    PORT_RANGE_END = 4499

    AWS_REGION = 'us-gov-west-1'

    # Path to VCR configuration file (source of truth for placeholder mappings)
    VCR_CONFIG_PATH = File.expand_path('../../spec/support/vcr.rb', __dir__)

    # Services that can be accessed directly (no tunnel needed)
    DIRECT_ACCESS_NAMESPACES = %w[lighthouse].freeze

    class << self
      # Parse vcr.rb to extract placeholder -> Settings path mappings
      # Returns hash like: { 'MHV_UHD_HOST' => 'mhv.uhd.host', 'MHV_SM_HOST' => 'mhv.api_gateway.hosts.sm_patient' }
      def parse_vcr_placeholders
        @vcr_placeholders ||= begin
          return {} unless File.exist?(VCR_CONFIG_PATH)

          content = File.read(VCR_CONFIG_PATH)
          placeholders = {}

          # Match patterns like: c.filter_sensitive_data('<MHV_UHD_HOST>') { Settings.mhv.uhd.host }
          # Also handles multi-line blocks
          content.scan(/filter_sensitive_data\(['"]<([^>]+)>['"]\)\s*(?:\{\s*([^}]+)\s*\}|do\s*\n?\s*([^e]+?)\s*end)/m) do |match|
            placeholder_name = match[0]
            settings_expr = (match[1] || match[2])&.strip

            next unless settings_expr&.start_with?('Settings.')

            # Extract the settings path: Settings.mhv.uhd.host -> mhv.uhd.host
            settings_path = settings_expr.sub(/^Settings\./, '').strip
            placeholders[placeholder_name] = settings_path
          end

          placeholders
        end
      end

      # Derive settings namespace from a full settings path
      # e.g., 'mhv.uhd.host' -> 'mhv.uhd', 'mhv.uhd.security_host' -> 'mhv.uhd'
      def settings_namespace_from_path(settings_path)
        parts = settings_path.split('.')
        # Remove the last part (usually 'host', 'url', 'api_key', etc.)
        # But handle special cases like 'mhv.api_gateway.hosts.sm_patient'
        if parts.length >= 2
          # Check if it looks like a host/url/key path
          if %w[host url api_key app_token security_host x_api_key].include?(parts.last)
            parts[0..-2].join('.')
          elsif parts[-2] == 'hosts'
            # Handle mhv.api_gateway.hosts.sm_patient -> mhv.sm (special case)
            derive_namespace_from_special_path(parts)
          else
            parts[0..-2].join('.')
          end
        else
          settings_path
        end
      end

      # Handle special path patterns
      def derive_namespace_from_special_path(parts)
        # mhv.api_gateway.hosts.sm_patient -> mhv.sm
        if parts.include?('api_gateway') && parts.include?('hosts')
          service_hint = parts.last # e.g., 'sm_patient'
          if service_hint.include?('sm')
            'mhv.sm'
          else
            parts[0..-2].join('.')
          end
        else
          parts[0..-2].join('.')
        end
      end

      # Build a mapping of placeholder names to their settings namespaces
      def placeholder_to_namespace
        @placeholder_to_namespace ||= begin
          mapping = {}
          parse_vcr_placeholders.each do |placeholder, settings_path|
            namespace = settings_namespace_from_path(settings_path)
            mapping[placeholder] = namespace
          end
          mapping
        end
      end

      # Group placeholders by their settings namespace
      def namespaces_to_placeholders
        @namespaces_to_placeholders ||= begin
          grouped = Hash.new { |h, k| h[k] = [] }
          placeholder_to_namespace.each do |placeholder, namespace|
            grouped[namespace] << placeholder
          end
          grouped
        end
      end

      def detect_from_cassette(_cassette_path, interactions = [])
        # Detect service based on VCR placeholder names found in cassette URIs
        # Uses vcr.rb as the source of truth
        detect_by_placeholders(interactions)
      end

      # Detects service based on VCR placeholder names in URIs
      # Dynamically reads from spec/support/vcr.rb
      def detect_by_placeholders(interactions)
        return nil if interactions.nil? || interactions.empty?

        uris = interactions.map { |i| i.dig(:request, :uri) }.compact
        return nil if uris.empty?

        # Check each placeholder from vcr.rb
        placeholder_to_namespace.each do |placeholder, namespace|
          # Match placeholders like <MHV_UHD_HOST> in URIs
          pattern = /<#{Regexp.escape(placeholder)}>/
          if uris.any? { |uri| uri.match?(pattern) }
            return build_service_result(namespace, placeholder)
          end
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
          connection_method: connection_method,
          placeholders: placeholders,
          detected_placeholder: detected_placeholder,
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
        AWS_REGION
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
        @vcr_placeholders = nil
        @placeholder_to_namespace = nil
        @namespaces_to_placeholders = nil
      end
    end
  end
end
