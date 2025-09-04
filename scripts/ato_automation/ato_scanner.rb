#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require 'fileutils'
require 'open3'
require 'pathname'

# ATO Scanner - Automatically scans repository for ATO-relevant information
# Helps answer annual security audit questions by gathering infrastructure data

class ATOScanner
  attr_reader :repo_path, :output_dir, :results

  def initialize(repo_path = Dir.pwd, output_dir = 'ato_audit_output')
    @repo_path = Pathname.new(repo_path).expand_path
    @output_dir = Pathname.new(output_dir).expand_path
    @results = {}
    FileUtils.mkdir_p(@output_dir)
  end

  def run
    puts "Starting ATO Scanner in #{repo_path}..."
    
    scan_security_configurations
    scan_dependencies
    scan_authentication_methods
    scan_data_handling
    scan_encryption_usage
    scan_api_endpoints
    scan_logging_configuration
    scan_environment_configs
    scan_database_security
    scan_external_integrations
    
    generate_report
    puts "Scan complete! Results saved to #{output_dir}"
  end