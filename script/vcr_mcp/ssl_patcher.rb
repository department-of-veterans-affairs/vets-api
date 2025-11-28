# frozen_string_literal: true

require_relative 'constants'

# rubocop:disable Rails/Delegate
module VcrMcp
  # Temporarily patches Faraday configurations to disable SSL verification
  # for VCR cassette re-recording through local tunnels
  class SslPatcher
    VETS_API_ROOT = Constants::VETS_API_ROOT

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
    SSL_DISABLE_CODE = <<~RUBY.freeze
      %<indent>s#{SSL_DISABLE_MARKER}
      %<indent>s%<conn>s.ssl.verify = false  # Temporary: disable SSL for VCR re-recording
      %<indent>s#{SSL_DISABLE_END_MARKER}
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

      return { error: "No Faraday.new block found to patch in #{file_path}" } if patched_content == content

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
        restore_from_backup(full_path, backup_path)
      elsif File.exist?(full_path) && file_patched?(full_path)
        remove_patch_from_file(full_path)
      else
        { error: "No backup or patch found for #{file_path}" }
      end
    end

    def restore_from_backup(full_path, backup_path)
      File.write(full_path, File.read(backup_path))
      File.delete(backup_path)
      {
        success: true,
        file: relative_path(full_path),
        message: "Restored #{relative_path(full_path)} from backup"
      }
    end

    def remove_patch_from_file(full_path)
      content = File.read(full_path)
      unpatched = remove_patch_markers(content)
      File.write(full_path, unpatched)
      {
        success: true,
        file: relative_path(full_path),
        message: "Removed SSL patch from #{relative_path(full_path)}"
      }
    end

    def patch_for_cassette(cassette_path)
      # Detect service from cassette
      require_relative 'service_config'
      service = ServiceConfig.detect_from_cassette(cassette_path, [])

      return { error: "Could not detect service for cassette: #{cassette_path}" } unless service

      # Find configuration files for this service
      config_files = find_config_files_for_service(service)

      if config_files.empty?
        return {
          error: "No configuration files found for service: #{service[:name]}",
          service: service[:name],
          suggestion: 'Try patching manually with vcr_patch_ssl tool'
        }
      end

      results = config_files.map { |f| patch_file(f) }

      {
        service: service[:name],
        results:,
        patched_files: results.select { |r| r[:success] }.map { |r| r[:file] },
        command_to_unpatch: "Use vcr_unpatch_ssl tool or run: git checkout #{config_files.map do |f|
          relative_path(f)
        end.join(' ')}"
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
      CONFIGURATION_PATTERNS.each_key do |pattern|
        Dir.glob(File.join(VETS_API_ROOT, pattern)).each do |file|
          files << relative_path(file) if file_patched?(file) && files.exclude?(relative_path(file))
        end
      end

      { files:, count: files.length }
    end

    private

    def resolve_path(path)
      resolved = path.start_with?('/') ? path : File.join(VETS_API_ROOT, path)
      # Resolve symlinks and normalize path to prevent directory traversal
      resolved = File.expand_path(resolved)
      unless resolved.start_with?(VETS_API_ROOT)
        raise ArgumentError, "Path '#{path}' resolves outside the vets-api directory"
      end

      resolved
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

          ssl_code = format(SSL_DISABLE_CODE, indent: "#{indent}  ", conn: conn_var)

          "#{match}\n#{ssl_code}"
        end
      end

      patched
    end

    def remove_patch_markers(content)
      # Remove everything between (and including) the markers
      content.gsub(
        /^.*#{Regexp.escape(SSL_DISABLE_MARKER)}.*$\n(.*\n)*?^.*#{Regexp.escape(SSL_DISABLE_END_MARKER)}.*$\n/, ''
      )
    end

    def find_config_files_for_service(service)
      files = find_files_from_service_hints(service)

      files = find_files_from_namespace(service[:settings_namespace]) if files.empty? && service[:settings_namespace]

      files.uniq
    end

    def find_files_from_service_hints(service)
      hints = service_file_hints[service[:key]] || []
      hints.filter_map do |hint|
        full_path = File.join(VETS_API_ROOT, hint)
        full_path if File.exist?(full_path)
      end
    end

    def service_file_hints
      {
        'mhv_sm' => ['lib/sm/configuration.rb'],
        'mhv_rx' => ['lib/rx/configuration.rb'],
        'mhv_mr' => ['lib/medical_records/configuration.rb'],
        'mhv_uhd' => ['lib/unified_health_data/configuration.rb'],
        'lighthouse_health' => ['lib/lighthouse/veterans_health/configuration.rb'],
        'mobile' => ['modules/mobile/app/services/mobile/v0/messaging/client.rb']
      }
    end

    def find_files_from_namespace(namespace)
      namespace_parts = namespace.split('.')
      search_patterns = [
        "lib/#{namespace_parts.join('/')}/configuration.rb",
        "lib/#{namespace_parts.join('_')}/configuration.rb",
        "lib/#{namespace_parts.last}/configuration.rb"
      ]

      search_patterns.flat_map { |pattern| Dir.glob(File.join(VETS_API_ROOT, pattern)) }
    end
  end
end
# rubocop:enable Rails/Delegate
