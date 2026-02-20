#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: ruby controller_error_audit.rb /path/to/vets-api
# Default: runs from current directory

ROOT = ARGV[0] || Dir.pwd

CONTROLLER_GLOBS = [
  'app/controllers/**/*.rb',
  'modules/*/app/controllers/**/*.rb'
].freeze

# These are framework-level handlers inherited from ApplicationController.
# A controller that only relies on these has no action-specific handling.
FRAMEWORK_RESCUES = %w[
  Common::Exceptions::BackendServiceException
  Common::Exceptions::Unauthorized
  Common::Exceptions::Forbidden
  Common::Exceptions::ResourceNotFound
  Common::Exceptions::ValidationErrors
  ActionController::ParameterMissing
  ActiveRecord::RecordNotFound
  Common::Exceptions::Base
].freeze

# ── Helpers ───────────────────────────────────────────────────────────────────

def find_all_controllers
  CONTROLLER_GLOBS.flat_map { |glob| Dir.glob(File.join(ROOT, glob)) }.uniq.sort
end

def read(path)
  File.read(path)
rescue => e
  warn "Could not read #{path}: #{e.message}"
  nil
end

def relative(path)
  path.sub("#{ROOT}/", '')
end

def module_name(source)
  source.scan(/^\s*(?:module|class)\s+(\S+)/).map(&:first).join('::')
end

def action_methods(source)
  # Public action methods — stop collecting at private/protected boundary
  actions = []
  in_private = false

  source.each_line do |line|
    in_private = true if line =~ /^\s*(private|protected)\s*$/
    next if in_private

    actions << Regexp.last_match(1) if line =~ /^\s*def\s+(\w+)/
  end

  actions - %w[initialize]
end

# Pull every rescue clause from the source with its exception list and whether it re-raises
def parse_rescue_blocks(source)
  blocks = []
  lines  = source.lines

  lines.each_with_index do |line, idx|
    next unless line =~ /^\s*rescue\b(.*)/

    exception_clause = Regexp.last_match(1).strip.split(/,\s*/).map(&:strip)
    exception_clause = ['StandardError (implicit)'] if exception_clause.empty?

    body   = []
    raises = false
    render = false

    rescue_indent = line[/^\s*/].length
    ((idx + 1)...lines.length).each do |j|
      l = lines[j]
      indent = l[/^\s*/].length
      break if indent <= rescue_indent && l =~ /^\s*(rescue|else|ensure|end)\b/

      body << l.rstrip
      raises = true if l =~ /\braise\b/
      render = true if l =~ /\brender\b|\bhead\b|\bredirect_to\b/
    end

    blocks << {
      exceptions: exception_clause,
      raises:,
      renders: render,
      body_lines: body
    }
  end

  blocks
end

# Rescue_from declarations at class level
def parse_rescue_from(source)
  source.scan(/rescue_from\s+([^\n,]+?)(?:\s*,\s*with:\s*:(\w+))?(?:\s*do|\n)/)
        .map { |exc, handler| { exception: exc.strip, handler: } }
end

def only_framework_rescues?(rescue_blocks)
  return true if rescue_blocks.empty?

  rescue_blocks.all? do |block|
    block[:exceptions].all? do |exc|
      FRAMEWORK_RESCUES.any? { |fw| exc.include?(fw) }
    end
  end
end

def classify(source)
  actions      = action_methods(source)
  rescues      = parse_rescue_blocks(source)
  rescue_froms = parse_rescue_from(source)

  has_rescue_from    = rescue_froms.any?
  has_action_rescues = rescues.any?
  source =~ /def\s+(index|show|create|update|destroy|new|edit|\w+)\b/ &&
    source =~ /\brescue\b/

  if !has_action_rescues && !has_rescue_from
    return {
      category: :no_handling,
      actions:,
      rescues: [],
      rescue_froms: []
    }
  end

  swallowed = rescues.select { |r| !r[:raises] && !r[:renders] }
  all_swallowed = rescues.any? && swallowed.size == rescues.size

  if all_swallowed && !has_rescue_from
    return {
      category: :rescue_swallows,
      actions:,
      rescues:,
      rescue_froms:
    }
  end

  partial = rescues.any? && swallowed.any? && !all_swallowed
  if partial
    return {
      category: :partial_handling,
      actions:,
      rescues:,
      rescue_froms:
    }
  end

  if only_framework_rescues?(rescues) && !has_rescue_from
    return {
      category: :framework_only,
      actions:,
      rescues:,
      rescue_froms:
    }
  end

  {
    category: :handled,
    actions:,
    rescues:,
    rescue_froms:
  }
end

# ── Main ──────────────────────────────────────────────────────────────────────

results = {
  no_handling: [], # No rescue or rescue_from anywhere in the controller
  rescue_swallows: [], # Has rescue blocks but all silently swallow errors
  partial_handling: [], # Some rescues handle, some swallow
  framework_only: [], # Only rescues framework base exceptions — no action-level specificity
  handled: [] # Has meaningful error handling
}

find_all_controllers.each do |path|
  source = read(path)
  next unless source
  next if action_methods(source).empty?

  # Skip base/application controllers — they define the framework handlers
  next if relative(path) =~ /application_controller|base_controller/

  info = classify(source)
  name = module_name(source)

  results[info[:category]] << {
    path: relative(path),
    name:,
    actions: info[:actions],
    rescues: info[:rescues],
    rescue_froms: info[:rescue_froms]
  }
end

# ── Report ────────────────────────────────────────────────────────────────────

SEPARATOR = ('─' * 80).freeze

def print_section(title, emoji, jobs, show_detail: false)
  puts "\n#{emoji}  #{title} (#{jobs.size})"
  puts SEPARATOR
  return puts "  none\n" if jobs.empty?

  jobs.each do |j|
    puts "  #{j[:name]}"
    puts "  #{j[:path]}"
    puts "  Actions: #{j[:actions].join(', ')}" if j[:actions].any?

    if show_detail
      j[:rescues].each do |r|
        excs   = r[:exceptions].join(', ')
        status = if r[:raises]
                   '✓ re-raises'
                 elsif r[:renders]
                   '~ renders error response'
                 else
                   '✗ swallows silently'
                 end
        puts "    rescue #{excs} → #{status}"
      end

      j[:rescue_froms].each do |rf|
        handler = rf[:handler] ? "with: :#{rf[:handler]}" : 'inline block'
        puts "    rescue_from #{rf[:exception]} → #{handler}"
      end
    end

    puts
  end
end

puts
puts '=' * 80
puts '  CONTROLLER ERROR HANDLING AUDIT'
puts "  Root: #{ROOT}"
puts "  Controllers found: #{results.values.sum(&:size)}"
puts '=' * 80

print_section(
  'NO ERROR HANDLING — any exception becomes a 500 with no logging or context',
  '🔴',
  results[:no_handling]
)

print_section(
  'RESCUE WITHOUT RESPONSE — exceptions caught but silently swallowed, client gets no error',
  '🟠',
  results[:rescue_swallows],
  show_detail: true
)

print_section(
  'PARTIAL HANDLING — some paths handled, others swallowed or unprotected',
  '🟡',
  results[:partial_handling],
  show_detail: true
)

print_section(
  'FRAMEWORK RESCUES ONLY — inherits base class handlers but no action-specific recovery',
  '🔵',
  results[:framework_only],
  show_detail: true
)

print_section(
  'HANDLED — has meaningful rescue or rescue_from coverage',
  '🟢',
  results[:handled]
)

# ── CSV ───────────────────────────────────────────────────────────────────────

csv_path = File.join(ROOT, 'controller_error_audit.csv')
File.open(csv_path, 'w') do |f|
  f.puts 'category,controller_name,path,actions,rescued_exceptions,rescue_froms'
  results.each do |category, controllers|
    controllers.each do |c|
      exceptions  = c[:rescues].map { |r| r[:exceptions].join(' | ') }.join(' ;; ')
      from_list   = c[:rescue_froms].map { |r| r[:exception] }.join(' | ')
      actions_str = c[:actions].join(' | ')
      row = [category, c[:name], c[:path], actions_str, exceptions, from_list]
      f.puts row.map { |v| "\"#{v}\"" }.join(',')
    end
  end
end

puts SEPARATOR
puts "  CSV written to: #{csv_path}"
puts SEPARATOR
