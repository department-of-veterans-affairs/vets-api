#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'pathname'

# Simplified ATO Scanner for vets-api repository
class ATOScannerSimple
  def initialize(repo_path = Dir.pwd)
    @repo_path = Pathname.new(repo_path)
    @results = {}
    @output_dir = @repo_path.join('ato_audit_output')
    FileUtils.mkdir_p(@output_dir)
  end

  def run
    puts "Starting ATO Security Scan..."
    puts "Repository: #{@repo_path}"
    puts "-" * 50
    
    scan_authentication
    scan_encryption
    scan_dependencies
    scan_logging
    scan_api_security
    
    save_results
    display_summary
  end

  private

  def scan_authentication
    puts "\n📍 Scanning Authentication..."
    @results[:authentication] = {
      devise_configured: file_exists?('config/initializers/devise.rb'),
      mfa_indicators: [],
      session_config: file_exists?('config/initializers/session_store.rb')
    }
    
    # Check for MFA/2FA implementations
    ['app/models/user.rb', 'app/controllers/application_controller.rb'].each do |file|
      if file_exists?(file)
        content = File.read(@repo_path.join(file)) rescue ""
        if content.match?(/two_factor|2fa|mfa|totp|authenticator/i)
          @results[:authentication][:mfa_indicators] << file
        end
      end
    end
    
    puts "  ✓ Devise configured: #{@results[:authentication][:devise_configured]}"
    puts "  ✓ MFA indicators found: #{@results[:authentication][:mfa_indicators].any?}"
  end

  def scan_encryption
    puts "\n📍 Scanning Encryption..."
    @results[:encryption] = {
      credentials_encrypted: file_exists?('config/credentials.yml.enc'),
      master_key: file_exists?('config/master.key'),
      ssl_configured: false
    }
    
    # Check for SSL/TLS configuration
    prod_config = @repo_path.join('config/environments/production.rb')
    if prod_config.exist?
      content = File.read(prod_config)
      @results[:encryption][:ssl_configured] = content.match?(/force_ssl|ssl|https/i)
    end
    
    puts "  ✓ Rails credentials encrypted: #{@results[:encryption][:credentials_encrypted]}"
    puts "  ✓ SSL forced in production: #{@results[:encryption][:ssl_configured]}"
  end

  def scan_dependencies
    puts "\n📍 Scanning Dependencies..."
    @results[:dependencies] = {
      gemfile_present: file_exists?('Gemfile'),
      gemfile_lock: file_exists?('Gemfile.lock'),
      security_gems: []
    }
    
    if @results[:dependencies][:gemfile_lock]
      gemfile_content = File.read(@repo_path.join('Gemfile.lock'))
      security_gems = %w[devise bcrypt jwt rack-attack brakeman bundler-audit secure_headers]
      security_gems.each do |gem|
        if gemfile_content.include?(gem)
          @results[:dependencies][:security_gems] << gem
        end
      end
    end
    
    puts "  ✓ Security gems found: #{@results[:dependencies][:security_gems].join(', ')}"
  end

  def scan_logging
    puts "\n📍 Scanning Logging Configuration..."
    @results[:logging] = {
      filter_parameters: false,
      log_level: nil
    }
    
    # Check application.rb for parameter filtering
    app_config = @repo_path.join('config/application.rb')
    if app_config.exist?
      content = File.read(app_config)
      @results[:logging][:filter_parameters] = content.match?(/filter_parameters/i)
    end
    
    # Check production log level
    prod_config = @repo_path.join('config/environments/production.rb')
    if prod_config.exist?
      content = File.read(prod_config)
      if match = content.match(/config\.log_level\s*=\s*:(\w+)/)
        @results[:logging][:log_level] = match[1]
      end
    end
    
    puts "  ✓ Parameter filtering enabled: #{@results[:logging][:filter_parameters]}"
    puts "  ✓ Production log level: #{@results[:logging][:log_level] || 'not set'}"
  end

  def scan_api_security
    puts "\n📍 Scanning API Security..."
    @results[:api_security] = {
      rack_attack: file_exists?('config/initializers/rack_attack.rb'),
      cors_configured: file_exists?('config/initializers/cors.rb'),
      routes_count: 0
    }
    
    # Count routes
    routes_file = @repo_path.join('config/routes.rb')
    if routes_file.exist?
      content = File.read(routes_file)
      @results[:api_security][:routes_count] = content.scan(/\b(get|post|put|patch|delete)\b/).count
    end
    
    puts "  ✓ Rate limiting (rack-attack): #{@results[:api_security][:rack_attack]}"
    puts "  ✓ CORS configured: #{@results[:api_security][:cors_configured]}"
    puts "  ✓ Approximate route count: #{@results[:api_security][:routes_count]}"
  end

  def file_exists?(path)
    @repo_path.join(path).exist?
  end

  def save_results
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    
    # Save JSON results
    json_file = @output_dir.join("ato_scan_#{timestamp}.json")
    File.write(json_file, JSON.pretty_generate(@results))
    
    # Save markdown summary
    md_file = @output_dir.join("ato_scan_summary_#{timestamp}.md")
    File.write(md_file, generate_markdown_summary)
    
    puts "\n✅ Results saved to:"
    puts "  - #{json_file}"
    puts "  - #{md_file}"
  end

  def generate_markdown_summary
    <<~MARKDOWN
      # ATO Security Scan Summary
      
      **Generated:** #{Time.now}  
      **Repository:** #{@repo_path}
      
      ## Authentication & Authorization
      - Devise configured: #{@results[:authentication][:devise_configured] ? '✅' : '❌'}
      - MFA/2FA indicators: #{@results[:authentication][:mfa_indicators].any? ? '✅' : '❌'}
      - Session configuration: #{@results[:authentication][:session_config] ? '✅' : '❌'}
      
      ## Data Protection & Encryption
      - Rails credentials encrypted: #{@results[:encryption][:credentials_encrypted] ? '✅' : '❌'}
      - Master key present: #{@results[:encryption][:master_key] ? '✅' : '❌'}
      - SSL forced in production: #{@results[:encryption][:ssl_configured] ? '✅' : '❌'}
      
      ## Dependencies & Vulnerability Management
      - Security gems: #{@results[:dependencies][:security_gems].join(', ')}
      
      ## Logging & Monitoring
      - Parameter filtering: #{@results[:logging][:filter_parameters] ? '✅' : '❌'}
      - Production log level: #{@results[:logging][:log_level] || 'not configured'}
      
      ## API Security
      - Rate limiting: #{@results[:api_security][:rack_attack] ? '✅' : '❌'}
      - CORS configured: #{@results[:api_security][:cors_configured] ? '✅' : '❌'}
      - Total routes: ~#{@results[:api_security][:routes_count]}
      
      ## Recommendations
      #{generate_recommendations}
    MARKDOWN
  end

  def generate_recommendations
    recommendations = []
    
    unless @results[:authentication][:mfa_indicators].any?
      recommendations << "- Consider implementing MFA for enhanced security"
    end
    
    unless @results[:encryption][:ssl_configured]
      recommendations << "- Ensure SSL is forced in production environment"
    end
    
    unless @results[:api_security][:rack_attack]
      recommendations << "- Implement rate limiting with rack-attack"
    end
    
    unless @results[:logging][:filter_parameters]
      recommendations << "- Enable parameter filtering to prevent PII in logs"
    end
    
    recommendations.empty? ? "None - security configurations look good!" : recommendations.join("\n")
  end

  def display_summary
    puts "\n" + "=" * 50
    puts "SCAN COMPLETE"
    puts "=" * 50
    
    total_checks = 0
    passed_checks = 0
    
    @results.each do |category, checks|
      checks.each do |check, value|
        total_checks += 1
        passed_checks += 1 if value == true || (value.is_a?(Array) && value.any?)
      end
    end
    
    puts "Security Score: #{passed_checks}/#{total_checks} checks passed"
    puts "\nNext steps:"
    puts "1. Review the generated reports in ato_audit_output/"
    puts "2. Address any identified gaps"
    puts "3. Use results for ATO audit responses"
  end
end

# Run the scanner
if __FILE__ == $0
  scanner = ATOScannerSimple.new
  scanner.run
end