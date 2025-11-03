# frozen_string_literal: true

require 'webrick'
require 'json'
require 'yaml'
require 'erb'
require 'base64'
require 'cgi'
require 'time'
require_relative 'cassette_finder'
require_relative 'cassette_parser'
require_relative 'test_analyzer'

module VcrInspector
  # Main web application using WEBrick
  class App
    attr_reader :cassette_root, :spec_root, :modules_root, :views_dir, :public_dir, :request

    def initialize
      # Get the actual file location, not execution location
      root = File.expand_path('../..', __dir__)
      @cassette_root = File.join(root, 'spec/support/vcr_cassettes')
      @spec_root = File.join(root, 'spec')
      @modules_root = File.join(root, 'modules')
      @views_dir = File.join(root, 'script/vcr_inspector/views')
      @public_dir = File.join(root, 'script/vcr_inspector/public')
      @request = nil
    end

    def self.run!(options = {})
      app = new
      port = options[:port] || 4567

      server = WEBrick::HTTPServer.new(
        Port: port,
        Logger: WEBrick::Log.new($stderr, WEBrick::Log::ERROR),
        AccessLog: []
      )

      server.mount_proc '/' do |req, res|
        app.handle_request(req, res)
      end

      puts "\n📼 VCR Inspector is running at http://localhost:#{port}"
      puts "   Press Ctrl+C to stop\n\n"

      trap('INT') { server.shutdown }
      trap('TERM') { server.shutdown }

      server.start
    end

    # Main request handler
    def handle_request(req, res)
      @request = req
      route_request(req, res)
    rescue => e
      handle_error(res, e)
    end

    def route_request(req, res)
      path = req.path
      method = req.request_method

      case [method, path]
      when ['GET', '/'] then handle_index(req, res)
      when ['GET', '/services'] then handle_services(req, res)
      when ['GET', '/search'] then handle_search(req, res)
      else
        route_path(req, res, path)
      end
    end

    def route_path(req, res, path)
      if path.start_with?('/cassette/')
        handle_cassette(req, res)
      elsif path == '/style.css'
        serve_file(res, File.join(public_dir, 'style.css'), 'text/css')
      elsif path == '/script.js'
        serve_file(res, File.join(public_dir, 'script.js'), 'application/javascript')
      else
        handle_not_found(req, res)
      end
    end

    def handle_error(res, error)
      res.status = 500
      res['Content-Type'] = 'text/html'
      error_trace = CGI.escapeHTML(error.backtrace.join("\n"))
      res.body = "<h1>500 Internal Server Error</h1><pre>#{CGI.escapeHTML(error.message)}\n\n#{error_trace}</pre>"
    end

    private

    def handle_index(req, res)
      @cassettes = CassetteFinder.all_cassettes(cassette_root)

      # Handle sorting
      sort = req.query['sort']
      if sort == 'recent'
        @cassettes = @cassettes.sort_by { |c| -c[:recorded_at].to_i }
      elsif sort == 'old'
        @cassettes = @cassettes.sort_by { |c| c[:recorded_at].to_i }
      end

      @stats = {
        total: @cassettes.length,
        services: CassetteFinder.group_by_service(@cassettes).keys.length
      }
      render(res, :index)
    end

    def handle_services(_req, res)
      @cassettes = CassetteFinder.all_cassettes(cassette_root)
      @services = CassetteFinder.group_by_service(@cassettes)
      render(res, :services)
    end

    def handle_search(req, res)
      query = req.query['q']
      sort = req.query['sort']
      filters = {
        service: req.query['service'],
        method: req.query['method'],
        status: req.query['status']
      }

      @cassettes = CassetteFinder.search(cassette_root, query, filters)

      # Handle sorting
      if sort == 'recent'
        @cassettes = @cassettes.sort_by { |c| -c[:recorded_at].to_i }
      elsif sort == 'old'
        @cassettes = @cassettes.sort_by { |c| c[:recorded_at].to_i }
      end

      @query = query
      @filters = filters
      render(res, :search_results)
    end

    def handle_cassette(req, res)
      cassette_path = req.path.sub('/cassette/', '')
      full_path = File.join(cassette_root, "#{cassette_path}.yml")

      return handle_not_found(req, res) unless File.exist?(full_path)

      @cassette_name = cassette_path
      @cassette = CassetteParser.parse(full_path)
      @file_info = File.stat(full_path)
      @recorded_at = extract_recorded_at(@cassette, @file_info)
      @tests_using = TestAnalyzer.find_tests_using(spec_root, modules_root, cassette_path)

      render(res, :cassette)
    end

    # rubocop:disable Rails/TimeZone - standalone script without ActiveSupport
    def extract_recorded_at(cassette, file_info)
      recorded_at = extract_from_interactions(cassette[:interactions])
      recorded_at ||= extract_from_raw_yaml(cassette[:raw])
      recorded_at || file_info.mtime
    end

    def extract_from_interactions(interactions)
      return nil unless interactions&.any?

      recorded_dates = interactions.map { |i| i[:recorded_at] }.compact
      recorded_dates.map do |d|
        Time.parse(d)
      rescue ArgumentError
        nil
      end.compact.max
    end

    def extract_from_raw_yaml(raw)
      return nil unless raw&.dig('recorded_at')

      Time.parse(raw['recorded_at'])
    rescue ArgumentError
      nil
    end
    # rubocop:enable Rails/TimeZone

    def handle_not_found(_req, res)
      res.status = 404
      render(res, :not_found)
    end

    def serve_file(res, file_path, content_type)
      if File.exist?(file_path)
        res['Content-Type'] = content_type
        res.body = File.read(file_path)
      else
        res.status = 404
        res['Content-Type'] = 'text/plain'
        res.body = 'Not Found'
      end
    end

    def render(res, template)
      res['Content-Type'] = 'text/html; charset=utf-8'
      layout_path = File.join(views_dir, 'layout.erb')
      template_path = File.join(views_dir, "#{template}.erb")

      # Render the template
      content = ERB.new(File.read(template_path), trim_mode: '-').result(binding)

      # Render layout with content
      @content = content
      res.body = ERB.new(File.read(layout_path), trim_mode: '-').result(binding)
    end

    # Helper methods for ERB templates
    # rubocop:disable Rails/Blank - standalone script without ActiveSupport
    def format_json(str)
      return str if str.nil? || str.empty?

      JSON.pretty_generate(JSON.parse(str))
    rescue JSON::ParserError
      str
    end
    # rubocop:enable Rails/Blank

    # Format date for display
    # rubocop:disable Rails/TimeZone - standalone script without ActiveSupport
    def format_date(date_str)
      return 'Unknown' if date_str.nil?

      Time.parse(date_str).strftime('%B %d, %Y at %I:%M %p')
    rescue ArgumentError
      date_str
    end

    def format_file_date(timestamp)
      timestamp = Time.parse(timestamp) if timestamp.is_a?(String)
      timestamp.strftime('%B %d, %Y')
    end

    # Cassette age indicator helper
    def cassette_age_indicator(timestamp)
      timestamp = Time.parse(timestamp) if timestamp.is_a?(String)
      days_old = ((Time.now - timestamp) / 86_400).to_i
      if days_old < 30
        '🆕'
      elsif days_old < 180
        '📼'
      elsif days_old < 365
        '⚠️'
      else
        '🕰️'
      end
    end
    # rubocop:enable Rails/TimeZone

    def http_method_emoji(method)
      case method.to_s.upcase
      when 'GET' then '🟢'
      when 'POST' then '🔵'
      when 'PUT' then '🟡'
      when 'PATCH' then '🟠'
      when 'DELETE' then '🔴'
      else '⚪'
      end
    end

    def status_class(code)
      case code.to_i
      when 200..299 then 'status-success'
      when 300..399 then 'status-redirect'
      when 400..499 then 'status-client-error'
      when 500..599 then 'status-server-error'
      else 'status-unknown'
      end
    end

    def truncate(text, length = 100)
      return text if text.length <= length

      "#{text[0...length]}..."
    end

    def safe_encode(str)
      return '' if str.nil?
      return str if str.encoding == Encoding::UTF_8 && str.valid_encoding?

      # Try to encode to UTF-8, replacing invalid characters
      str.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    rescue
      str.force_encoding('UTF-8')
    end

    def highlight_json(json_str)
      CGI.escapeHTML(safe_encode(json_str))
    end

    # rubocop:disable Rails/Blank - standalone script without ActiveSupport
    def decode_base64_if_needed(body_str)
      return body_str if body_str.nil? || body_str.empty?

      if body_str.match?(%r{^[A-Za-z0-9+/]+=*$}) && body_str.length > 100
        begin
          decoded = Base64.decode64(body_str)
          return decoded if decoded.valid_encoding?
        rescue
          # Not base64, return original
        end
      end
      body_str
    end
  end
  # rubocop:enable Rails/Blank
end
