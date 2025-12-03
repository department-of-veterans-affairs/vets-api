# frozen_string_literal: true

require_relative 'constants'
require_relative 'inspector'
require_relative 'spec_finder'
require_relative 'service_config'

module VcrMcp
  # Generates instructions for re-recording a VCR cassette
  class PreparationGuide
    VETS_API_ROOT = Constants::VETS_API_ROOT
    CASSETTE_ROOT = Constants::CASSETTE_ROOT

    def self.generate(cassette_path, environment: 'staging')
      new(cassette_path, environment).generate
    end

    def initialize(cassette_path, environment)
      @cassette_path = cassette_path
      @environment = environment
    end

    def generate
      # Inspect the cassette
      inspect_result = Inspector.inspect(@cassette_path)

      return { error: inspect_result[:error], matches: inspect_result[:matches] } if inspect_result[:error]

      # Find the full path
      full_path = find_full_path

      # Detect service
      service = ServiceConfig.detect_from_cassette(@cassette_path, inspect_result[:interactions])

      # Find specs using this cassette
      spec_result = SpecFinder.find(@cassette_path)

      # Generate the guide
      {
        cassette: @cassette_path,
        full_path: relative_path(full_path),
        interactions: inspect_result[:interactions].length,
        service:,
        specs: spec_result[:specs],
        guide: build_guide(full_path, service, spec_result, inspect_result)
      }
    end

    private

    def find_full_path
      result = Inspector.find_cassette(@cassette_path)
      return result if result.is_a?(String)

      # If multiple matches, use the first one
      result.is_a?(Array) ? result.first : nil
    end

    def relative_path(path)
      return nil unless path

      path.sub("#{VETS_API_ROOT}/", '')
    end

    def build_guide(full_path, service, spec_result, inspect_result)
      sections = []

      sections << build_header_section(full_path, inspect_result)
      sections << build_service_section(service, inspect_result)
      sections << build_settings_section(service)
      sections << build_tunnel_section(service)
      sections << build_local_settings_section(service)
      sections << build_backup_section(full_path)
      sections << build_spec_section(spec_result)
      sections << build_cleanup_section

      sections.join("\n")
    end

    def build_header_section(full_path, inspect_result)
      uris = inspect_result[:interactions].map { |i| i.dig(:request, :uri) }.compact.uniq

      <<~HEADER
        #{'=' * 80}
        VCR RE-RECORD PREPARATION
        #{'=' * 80}

        CASSETTE: #{@cassette_path}
        LOCATION: #{relative_path(full_path) || 'Not found'}
        INTERACTIONS: #{inspect_result[:interactions].length}
        ENVIRONMENT: #{@environment}

        ENDPOINTS CALLED:
        #{uris.map { |u| "  - #{u}" }.join("\n")}
      HEADER
    end

    def build_service_section(service, inspect_result)
      if service
        build_detected_service_section(service)
      else
        build_undetected_service_section(inspect_result)
      end
    end

    def build_detected_service_section(service)
      connection = service[:connection_method] == :direct ? 'Direct (may not need tunnel)' : 'Forward Proxy Tunnel'

      <<~SERVICE

        #{'=' * 80}
        SERVICE DETECTION
        #{'=' * 80}

        Detected: #{service[:name]}
        Service Key: #{service[:key]}
        Settings Namespace: #{service[:settings_namespace]}
        Connection Method: #{connection}
      SERVICE
    end

    def build_undetected_service_section(inspect_result)
      hosts = extract_hosts_from_interactions(inspect_result)

      <<~SERVICE

        #{'=' * 80}
        SERVICE DETECTION
        #{'=' * 80}

        ⚠️  Could not auto-detect service from cassette path or URIs.

        Hosts found in cassette:
        #{hosts.map { |h| "  - #{h}" }.join("\n")}

        You may need to manually determine:
        1. Which settings namespace to use
        2. What remote host to tunnel to
        3. How to authenticate
      SERVICE
    end

    def extract_hosts_from_interactions(inspect_result)
      uris = inspect_result[:interactions].map { |i| i.dig(:request, :uri) }.compact
      uris.filter_map do |u|
        URI.parse(u).host
      rescue URI::InvalidURIError
        nil
      end.uniq
    end

    def build_settings_section(service)
      return '' unless service&.dig(:settings_namespace)

      <<~SETTINGS

        #{'=' * 80}
        STEP 1: FETCH SETTINGS & START TUNNEL
        #{'=' * 80}

        Run sync-settings to fetch credentials AND start the tunnel:

          ./script/sync-settings #{service[:settings_namespace]} #{@environment}

        This script will:
          1. Fetch credentials from AWS Parameter Store
          2. Update config/settings.local.yml with the required settings
          3. Find a forward proxy instance in #{@environment}
          4. Start an SSM tunnel to the remote host

        The tunnel runs in the foreground - keep this terminal open.

        TIP: Run sync-settings in a separate terminal so you can run specs
        in your main terminal while the tunnel stays connected.
      SETTINGS
    end

    def build_tunnel_section(_service)
      # Tunnel setup is now handled by sync-settings
      ''
    end

    def build_local_settings_section(service)
      return '' unless service&.dig(:settings_namespace)
      return '' if service[:connection_method] == :direct

      namespace_parts = service[:settings_namespace].split('.')

      yaml_structure = namespace_parts.each_with_index.reduce('') do |acc, (part, idx)|
        indent = '  ' * idx
        acc + "#{indent}#{part}:\n"
      end
      final_indent = '  ' * namespace_parts.length
      yaml_structure += "#{final_indent}host: \"https://localhost:<PORT>\""

      <<~SETTINGS

        #{'=' * 80}
        STEP 2: UPDATE TEST SETTINGS (if needed)
        #{'=' * 80}

        sync-settings updates settings.local.yml, but specs use test environment.
        If the host isn't automatically overridden, add to config/settings/test.local.yml:

        #{yaml_structure}

        Replace <PORT> with the local port shown by sync-settings (usually 4443).

        NOTE: You may not need this step if your test environment already
        inherits from settings.local.yml or uses the same host configuration.
      SETTINGS
    end

    def build_backup_section(full_path)
      return '' unless full_path

      rel_path = relative_path(full_path)

      <<~BACKUP

        #{'=' * 80}
        STEP 3: BACKUP & DELETE CASSETTE
        #{'=' * 80}

          # Backup:
          cp #{rel_path} \\
             #{rel_path}.bak

          # Delete to force re-record:
          rm #{rel_path}

        VCR will only record if the cassette file doesn't exist.
      BACKUP
    end

    def build_spec_section(spec_result)
      if spec_result[:specs].empty?
        <<~SPECS

          #{'=' * 80}
          STEP 4: RUN SPEC TO RECORD
          #{'=' * 80}

          ⚠️  No specs found using this cassette!

          Search manually:
            grep -r "#{@cassette_path}" spec/ modules/*/spec/

          Or create a new spec that uses this cassette.
        SPECS
      else
        spec_list = spec_result[:specs].map do |spec|
          "  - #{spec[:file]}:#{spec[:line]}"
        end.join("\n")

        first_spec = spec_result[:specs].first
        run_command = "bundle exec rspec #{first_spec[:file]}:#{first_spec[:line]}"

        <<~SPECS

          #{'=' * 80}
          STEP 4: RUN SPEC TO RECORD
          #{'=' * 80}

          Specs using this cassette:
          #{spec_list}

          Run with forward proxy CA (recommended for local tunnels):
            SSL_CERT_FILE=config/ca-trust/fwdproxy.crt \\
              #{run_command}

        SPECS
      end
    end

    def build_cleanup_section
      <<~CLEANUP

        #{'=' * 80}
        STEP 5: VALIDATE & CLEANUP
        #{'=' * 80}

        After recording:

          [ ] Verify cassette was created with expected interactions
          [ ] Validate for sensitive data:
              Use vcr_validate_cassette tool or:
              grep -E '(Bearer|token|\\d{10}V\\d{6}|\\d{3}-\\d{2}-\\d{4})' <cassette>
          [ ] Compare with backup: diff *.yml *.yml.bak
          [ ] Remove/reset config/settings/test.local.yml (if you modified it)
          [ ] Stop the SSM tunnel (Ctrl+C in sync-settings terminal)
          [ ] Run specs to confirm cassette works:
              bundle exec rspec <spec_file>
          [ ] Delete backup file if everything looks good

        #{'=' * 80}
      CLEANUP
    end
  end
end
