# frozen_string_literal: true

module VcrMcp
  # Temporarily patches Faraday configurations to disable SSL verification
  # for VCR cassette re-recording through local tunnels
  class SslPatcher
    VETS_API_ROOT = File.expand_path('../..', __dir__)

    # Known configuration files and their Faraday connection patterns
    CONFIGURATION_PATTERNS = {
      # Pattern: file glob => array of patterns to find Faraday.new calls
      'lib/**/configuration.rb' => [
        # Standard Faraday.new with block
        /^(\s*)(Faraday\.new\([^)]*\)\s*do\s*\|(\w+)\|)/,
        # Faraday.new with options hash
        /^(\s*)(Faraday\.new\(\s*\w+\s*,\s*[^)]*\)\s*do\s*\|(\w+)\|)/
      ],
      'lib/**/client.rb' => [
        /^(\s*)(Faraday\.new\([^)]*\)\s*do\s*\|(\w+)\|)/
      ],
      'modules/**/configuration.rb' => [
        /^(\s*)(Faraday\.new\([^)]*\)\s*do\s*\|(\w+)\|)/
      ]
    }.freeze

    # The SSL disable line we inject
    SSL_DISABLE_MARKER = '# VCR_SSL_PATCH_START'
    SSL_DISABLE_END_MARKER = '# VCR_SSL_PATCH_END'
    SSL_DISABLE_CODE = <<~RUBY
      %{indent}#{SSL_DISABLE_MARKER}
      %{indent}%{conn}.ssl.verify = false  # Temporary: disable SSL for VCR re-recording
      %{indent}#{SSL_DISABLE_END_MARKER}
    RUBY

    class << self
      def patch_file(file_path)
        new.patch_file(file_path)
      end

      def unpatch_file(file_path)
        new.unpatch_file(file_path)
      end

      def patch_for_cassette(cassette_path)
        new.patch_for_cassette(cassette_path)
      end

      def unpatch_all
        new.unpatch_all
      end

      def list_patched_files
        new.list_patched_files
      end
    end

    def patch_file(file_path)
      full_path = resolve_path(file_path)
      return { error: "File not found: #{file_path}" } unless File.exist?(full_path)
      return { error: "File already patched: #{file_path}", already_patched: true } if file_patched?(full_path)

      content = File.read(full_path)
      patched_content = apply_patch(content)

      if patched_content == content
        return { error: "No Faraday.new block found to patch in #{file_path}" }
      end

      # Create backup
      backup_path = "#{full_path}.vcr_ssl_backup"
      File.write(backup_path, content)

      # Write patched content
      File.write(full_path, patched_content)

      {
        success: true,
        file: relative_path(full_path),
        backup: relative_path(backup_path),
        message: "Patched #{relative_path(full_path)} to disable SSL verification"
      }
    end

    def unpatch_file(file_path)
      full_path = resolve_path(file_path)
      backup_path = "#{full_path}.vcr_ssl_backup"

      if File.exist?(backup_path)
        # Restore from backup
        File.write(full_path, File.read(backup_path))
        File.delete(backup_path)
        {
          success: true,
          file: relative_path(full_path),
          message: "Restored #{relative_path(full_path)} from backup"
        }
      elsif File.exist?(full_path) && file_patched?(full_path)
        # Remove patch markers manually
        content = File.read(full_path)
        unpatched = remove_patch_markers(content)
        File.write(full_path, unpatched)
        {
          success: true,
          file: relative_path(full_path),
          message: "Removed SSL patch from #{relative_path(full_path)}"
        }
      else
        { error: "No backup or patch found for #{file_path}" }
      end
    end

    def patch_for_cassette(cassette_path)
      # Detect service from cassette
      require_relative 'service_config'
      service = ServiceConfig.detect_from_cassette(cassette_path, [])

      unless service
        return { error: "Could not detect service for cassette: #{cassette_path}" }
      end

      # Find configuration files for this service
      config_files = find_config_files_for_service(service)

      if config_files.empty?
        return {
          error: "No configuration files found for service: #{service[:name]}",
          service: service[:name],
          suggestion: "Try patching manually with vcr_patch_ssl tool"
        }
      end

      results = config_files.map { |f| patch_file(f) }

      {
        service: service[:name],
        results: results,
        patched_files: results.select { |r| r[:success] }.map { |r| r[:file] },
        command_to_unpatch: "Use vcr_unpatch_ssl tool or run: git checkout #{config_files.map { |f| relative_path(f) }.join(' ')}"
      }
    end

    def unpatch_all
      patched = list_patched_files
      results = patched[:files].map { |f| unpatch_file(f) }

      {
        unpatched: results.select { |r| r[:success] }.map { |r| r[:file] },
        errors: results.select { |r| r[:error] }.map { |r| r[:error] }
      }
    end

    def list_patched_files
      files = []

      # Find all .vcr_ssl_backup files
      Dir.glob(File.join(VETS_API_ROOT, '**', '*.vcr_ssl_backup')).each do |backup|
        original = backup.sub('.vcr_ssl_backup', '')
        files << relative_path(original) if File.exist?(original)
      end

      # Also check for files with patch markers but no backup
      CONFIGURATION_PATTERNS.keys.each do |pattern|
        Dir.glob(File.join(VETS_API_ROOT, pattern)).each do |file|
          if file_patched?(file) && !files.include?(relative_path(file))
            files << relative_path(file)
          end
        end
      end

      { files: files, count: files.length }
    end

    private

    def resolve_path(path)
      return path if path.start_with?('/')

      File.join(VETS_API_ROOT, path)
    end

    def relative_path(path)
      path.sub("#{VETS_API_ROOT}/", '')
    end

    def file_patched?(path)
      return false unless File.exist?(path)

      File.read(path).include?(SSL_DISABLE_MARKER)
    end

    def apply_patch(content)
      patched = content.dup

      CONFIGURATION_PATTERNS.values.flatten.each do |pattern|
        patched = patched.gsub(pattern) do |match|
          indent = Regexp.last_match(1)
          conn_var = Regexp.last_match(3)

          ssl_code = format(SSL_DISABLE_CODE, indent: indent + '  ', conn: conn_var)

          "#{match}\n#{ssl_code}"
        end
      end

      patched
    end

    def remove_patch_markers(content)
      # Remove everything between (and including) the markers
      content.gsub(/^.*#{Regexp.escape(SSL_DISABLE_MARKER)}.*$\n(.*\n)*?^.*#{Regexp.escape(SSL_DISABLE_END_MARKER)}.*$\n/, '')
    end

    def find_config_files_for_service(service)
      files = []

      # Map service keys to likely configuration file locations
      service_file_hints = {
        'mhv_sm' => ['lib/sm/configuration.rb'],
        'mhv_rx' => ['lib/rx/configuration.rb'],
        'mhv_mr' => ['lib/medical_records/configuration.rb'],
        'mhv_uhd' => ['lib/unified_health_data/configuration.rb'],
        'lighthouse_health' => ['lib/lighthouse/veterans_health/configuration.rb'],
        'mobile' => ['modules/mobile/app/services/mobile/v0/messaging/client.rb']
      }

      hints = service_file_hints[service[:key]] || []
      hints.each do |hint|
        full_path = File.join(VETS_API_ROOT, hint)
        files << full_path if File.exist?(full_path)
      end

      # If no hints matched, search by settings namespace
      if files.empty? && service[:settings_namespace]
        namespace_parts = service[:settings_namespace].split('.')
        search_patterns = [
          "lib/#{namespace_parts.join('/')}/configuration.rb",
          "lib/#{namespace_parts.join('_')}/configuration.rb",
          "lib/#{namespace_parts.last}/configuration.rb"
        ]

        search_patterns.each do |pattern|
          Dir.glob(File.join(VETS_API_ROOT, pattern)).each { |f| files << f }
        end
      end

      files.uniq
    end
  end
end
