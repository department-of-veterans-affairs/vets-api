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
      root = File.expand_path('../../..', __FILE__)
      @cassette_root = File.join(root, 'spec/support/vcr_cassettes')
      @spec_root = File.join(root, 'spec')
      @modules_root = File.join(root, 'modules')
      @views_dir = File.join(root, 'lib/vcr_inspector/views')
      @public_dir = File.join(root, 'lib/vcr_inspector/public')
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

    def handle_request(req, res)
      @request = req
      path = req.path
      method = req.request_method

      case [method, path]
      when ['GET', '/']
        handle_index(req, res)
      when ['GET', '/services']
        handle_services(req, res)
      when ['GET', '/search']
        handle_search(req, res)
      else
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
    rescue StandardError => e
      res.status = 500
      res['Content-Type'] = 'text/html'
      res.body = "<h1>500 Internal Server Error</h1><pre>#{CGI.escapeHTML(e.message)}\n\n#{CGI.escapeHTML(e.backtrace.join("\n"))}</pre>"
    end

    private

    def handle_index(_req, res)
      @cassettes = CassetteFinder.all_cassettes(cassette_root)
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
      filters = {
        service: req.query['service'],
        method: req.query['method'],
        status: req.query['status']
      }
      
      @cassettes = CassetteFinder.search(cassette_root, query, filters)
      @query = query
      @filters = filters
      render(res, :search_results)
    end

    def handle_cassette(req, res)
      cassette_path = req.path.sub('/cassette/', '')
      full_path = File.join(cassette_root, "#{cassette_path}.yml")
      
      unless File.exist?(full_path)
        return handle_not_found(req, res)
      end

      @cassette_name = cassette_path
      @cassette = CassetteParser.parse(full_path)
      @file_info = File.stat(full_path)
      @tests_using = TestAnalyzer.find_tests_using(spec_root, modules_root, cassette_path)
      
      render(res, :cassette)
    end

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
    def format_json(str)
      return str if str.nil? || str.empty?
      
      JSON.pretty_generate(JSON.parse(str))
    rescue JSON::ParserError
      str
    end

    def format_date(date_str)
      return 'Unknown' if date_str.nil?
      
      Time.parse(date_str).strftime('%B %d, %Y at %I:%M %p')
    rescue ArgumentError
      date_str
    end

    def format_file_date(timestamp)
      timestamp.strftime('%B %d, %Y')
    end

    def cassette_age_indicator(timestamp)
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

    def highlight_json(json_str)
      CGI.escapeHTML(json_str)
    end

    def decode_base64_if_needed(body_str)
      return body_str if body_str.nil? || body_str.empty?
      
      if body_str.match?(/^[A-Za-z0-9+\/]+=*$/) && body_str.length > 100
        begin
          decoded = Base64.decode64(body_str)
          return decoded if decoded.valid_encoding?
        rescue StandardError
          # Not base64, return original
        end
      end
      body_str
    end
  end
end
