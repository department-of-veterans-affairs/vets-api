#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to lint controllers, services, and jobs for missing parameter validation
# This runs in CI/CD to fail the build if violations are found
#
# Usage:
#   ruby parameter_validation_linter.rb /path/to/vets-api
#
# Exit codes:
#   0 - No violations found
#   1 - Violations found (fails CI build)

require 'json'

class ParameterValidationLinter
  REQUIRED_PARAMS = %w[icn participant_id edipi ssn user_uuid birls_id vet360_id].freeze

  attr_reader :violations

  def initialize(base_path)
    @base_path = base_path
    @violations = []
  end

  def lint
    puts "🔍 Linting for parameter validation issues...\n\n"

    check_services_have_validation
    check_controllers_validate_before_instantiation

    report

    @violations.empty? ? 0 : 1
  end

  private

  def check_services_have_validation
    puts "Checking services for parameter validation in initialize..."

    service_files = find_ruby_files([
      'app/services',
      'lib',
      'modules/*/app/services',
      'modules/*/lib'
    ])

    service_files.each do |file|
      check_service_file(file)
    end

    puts "  ✓ Checked #{service_files.length} service files\n\n"
  end

  def check_service_file(file)
    content = File.read(file)

    # Find initialize method
    return unless content =~ /def\s+initialize\s*\((.*?)\)/m

    init_params = $1

    REQUIRED_PARAMS.each do |param|
      next unless init_params.include?(param)

      # Check if parameter is used in URL building or instance variable assignment
      uses_param = (
        content =~ /@#{param}\s*=/ ||
        content =~ /"[^"]*\#\{[^}]*#{param}/ ||
        content =~ /'[^']*\#\{[^}]*#{param}/ ||
        content =~ /\.get\(.*#{param}/ ||
        content =~ /\.post\(.*#{param}/
      )

      next unless uses_param

      # Check for validation
      has_validation = check_service_validation(content, param)

      unless has_validation
        add_violation(
          type: 'service_missing_validation',
          file: file.gsub(@base_path, ''),
          parameter: param,
          message: "Service accepts '#{param}' but doesn't validate it in initialize",
          severity: 'error'
        )
      end
    end
  end

  def check_service_validation(content, param)
    validation_patterns = [
      /raise\s+ArgumentError.*unless\s+#{param}/,
      /raise\s+.*'#{param}.*required'/i,
      /raise.*unless.*#{param}\.present\?/,
      /return.*unless.*#{param}\.present\?/,
      /#{param}\s*=.*or\s+raise/
    ]

    validation_patterns.any? { |pattern| content =~ pattern }
  end

  def check_controllers_validate_before_instantiation
    puts "Checking controllers validate parameters before service instantiation..."

    controller_files = find_ruby_files([
      'app/controllers',
      'modules/*/app/controllers'
    ])

    controller_files.each do |file|
      check_controller_file(file)
    end

    puts "  ✓ Checked #{controller_files.length} controller files\n\n"
  end

  def check_controller_file(file)
    content = File.read(file)

    # Find service/job instantiations
    content.scan(/(\w+(?:Service|Job|Provider))\.(new|perform_async|perform_later)\s*\((.*?)\)/m) do |match|
      class_name, method, params = match

      REQUIRED_PARAMS.each do |param|
        next unless params.include?(param) ||
                    params.include?("@#{param}") ||
                    params.include?("current_user.#{param}")

        # Find the line number
        line_num = content[0..content.index(match[0])].count("\n") + 1

        # Get context around the line
        lines = content.split("\n")
        start_line = [line_num - 20, 0].max
        context = lines[start_line...line_num].join("\n")

        # Check for validation
        has_validation = check_controller_validation(context, param)

        unless has_validation
          add_violation(
            type: 'controller_missing_validation',
            file: file.gsub(@base_path, ''),
            line: line_num,
            parameter: param,
            service: class_name,
            message: "Controller calls #{class_name}.#{method} with '#{param}' without validating it first",
            severity: 'error'
          )
        end
      end
    end
  end

  def check_controller_validation(context, param)
    validation_patterns = [
      /return.*unless.*#{param}/,
      /return.*if.*#{param}\.blank\?/,
      /return.*if.*#{param}\.nil\?/,
      /render.*unless.*#{param}/,
      /render.*if.*#{param}\.blank\?/,
      /render.*if.*#{param}\.nil\?/,
      /unless.*#{param}\.present\?/,
      /before_action.*validate.*#{param}/,
      /validate.*#{param}/
    ]

    validation_patterns.any? { |pattern| context =~ pattern }
  end

  def find_ruby_files(paths)
    paths.flat_map do |path|
      Dir.glob(File.join(@base_path, path, '**/*.rb'))
    end.uniq
  end

  def add_violation(violation)
    @violations << violation
  end

  def report
    if @violations.empty?
      puts "✅ No parameter validation violations found!"
      puts ""
      return
    end

    puts "❌ Found #{@violations.length} parameter validation violations\n\n"

    # Group by type
    by_type = @violations.group_by { |v| v[:type] }

    # Report services
    if by_type['service_missing_validation']
      puts "Service Violations (#{by_type['service_missing_validation'].length}):"
      puts "=" * 80
      by_type['service_missing_validation'].each do |v|
        puts "  ❌ #{v[:file]}"
        puts "     Parameter: #{v[:parameter]}"
        puts "     Issue: #{v[:message]}"
        puts ""
      end
    end

    # Report controllers
    if by_type['controller_missing_validation']
      puts "Controller Violations (#{by_type['controller_missing_validation'].length}):"
      puts "=" * 80
      by_type['controller_missing_validation'].each do |v|
        puts "  ❌ #{v[:file]}:#{v[:line]}"
        puts "     Service: #{v[:service]}"
        puts "     Parameter: #{v[:parameter]}"
        puts "     Issue: #{v[:message]}"
        puts ""
      end
    end

    puts "=" * 80
    puts "💡 How to fix:"
    puts ""
    puts "For services, add validation in initialize:"
    puts "  def initialize(icn)"
    puts "    raise ArgumentError, 'ICN is required' unless icn.present?"
    puts "    @icn = icn"
    puts "  end"
    puts ""
    puts "For controllers, validate before calling services:"
    puts "  def show"
    puts "    return render_error unless current_user.icn.present?"
    puts "    service = SomeService.new(current_user.icn)"
    puts "  end"
    puts ""

    # Save JSON report
    File.write('parameter_validation_report.json', JSON.pretty_generate({
      summary: {
        total_violations: @violations.length,
        by_type: by_type.transform_values(&:length)
      },
      violations: @violations
    }))

    puts "📄 Full report saved to: parameter_validation_report.json"
    puts ""
  end
end

# Main execution
if __FILE__ == $0
  if ARGV.empty?
    puts "Usage: ruby parameter_validation_linter.rb /path/to/vets-api"
    exit 1
  end

  base_path = ARGV[0]

  unless File.directory?(base_path)
    puts "Error: #{base_path} is not a valid directory"
    exit 1
  end

  linter = ParameterValidationLinter.new(base_path)
  exit_code = linter.lint

  exit exit_code
end

