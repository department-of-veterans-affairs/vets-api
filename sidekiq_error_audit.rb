#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: ruby sidekiq_error_audit.rb /path/to/vets-api
# Default: runs from current directory
# rubocop:disable Lint/AmbiguousRange
ROOT = ARGV[0] || Dir.pwd

SIDEKIQ_GLOBS = [
  'app/sidekiq/**/*.rb',
  'modules/*/app/sidekiq/**/*.rb'
].freeze

# ── Helpers ───────────────────────────────────────────────────────────────────

def find_all_jobs
  SIDEKIQ_GLOBS.flat_map { |glob| Dir.glob(File.join(ROOT, glob)) }.uniq.sort
end

def read(path)
  File.read(path)
rescue => e
  warn "Could not read #{path}: #{e.message}"
  nil
end

# Returns every `rescue` block as a hash:
#   { exception: String, body_lines: [String], raises: Boolean }
def parse_rescue_blocks(source)
  blocks = []
  lines  = source.lines

  lines.each_with_index do |line, idx|
    next unless line =~ /^\s*rescue\b(.*)/

    exception_clause = $1.strip.then { |s| s.empty? ? 'StandardError (implicit)' : s }
    body = []
    raises = false

    # Collect lines until next rescue/else/ensure/end at same or lower indent
    rescue_indent = line[/^\s*/].length
    (idx + 1...lines.length).each do |j|
      l = lines[j]
      indent = l[/^\s*/].length
      break if indent <= rescue_indent && l =~ /^\s*(rescue|else|ensure|end)\b/

      body << l.rstrip
      raises = true if l =~ /\braise\b/
    end

    blocks << { exception: exception_clause, body_lines: body, raises: raises }
  end

  blocks
end

def has_perform_method?(source)
  source =~ /def\s+perform\b/
end

def rescue_blocks_cover_perform?(source)
  # Rough heuristic: rescue appears after `def perform`
  perform_pos = source.index(/def\s+perform\b/)
  return false unless perform_pos

  source[perform_pos..].match?(/\brescue\b/)
end

def classify(path, source)
  rescues = parse_rescue_blocks(source)
  perform_covered = rescue_blocks_cover_perform?(source)

  if rescues.empty? || !perform_covered
    return { category: :no_rescue, rescues: [] }
  end

  all_raise    = rescues.all? { |r| r[:raises] }
  none_raise   = rescues.none? { |r| r[:raises] }
  some_raise   = !all_raise && !none_raise

  if none_raise
    { category: :rescue_no_raise, rescues: rescues }
  elsif some_raise
    { category: :rescue_partial_raise, rescues: rescues }
  else
    { category: :rescue_all_raise, rescues: rescues }
  end
end

def relative(path)
  path.sub("#{ROOT}/", '')
end

def module_name(source)
  names = source.scan(/^\s*(?:module|class)\s+(\S+)/).map(&:first)
  names.join('::')
end

# ── Main ──────────────────────────────────────────────────────────────────────

results = {
  no_rescue:             [],   # No rescue at all in perform
  rescue_no_raise:       [],   # Rescues but swallows — never re-raises
  rescue_partial_raise:  [],   # Rescues multiple things, re-raises only some
  rescue_all_raise:      []    # Rescues and always re-raises (good)
}

find_all_jobs.each do |path|
  source = read(path)
  next unless source && has_perform_method?(source)

  info     = classify(path, source)
  job_name = module_name(source)

  results[info[:category]] << {
    path:    relative(path),
    name:    job_name,
    rescues: info[:rescues]
  }
end

# ── Report ────────────────────────────────────────────────────────────────────

SEPARATOR = ('─' * 80).freeze

def print_section(title, emoji, jobs, show_rescue_detail: false)
  puts "\n#{emoji}  #{title} (#{jobs.size})"
  puts SEPARATOR
  return puts "  none\n" if jobs.empty?

  jobs.each do |job|
    puts "  #{job[:name]}"
    puts "  #{job[:path]}"

    if show_rescue_detail && job[:rescues].any?
      job[:rescues].each do |r|
        status = r[:raises] ? '✓ raises' : '✗ swallows'
        puts "    rescue #{r[:exception]} → #{status}"
      end
    end

    puts
  end
end

puts
puts '=' * 80
puts '  SIDEKIQ JOB ERROR HANDLING AUDIT'
puts "  Root: #{ROOT}"
puts "  Jobs found: #{results.values.sum(&:size)}"
puts '=' * 80

print_section(
  'NO RESCUE — errors will crash the job and trigger Sidekiq retry',
  '🔴',
  results[:no_rescue]
)

print_section(
  'RESCUE WITHOUT RAISE — errors are silently swallowed, no retry triggered',
  '🟠',
  results[:rescue_no_raise],
  show_rescue_detail: true
)

print_section(
  'PARTIAL RAISE — some rescued errors re-raise, others are swallowed',
  '🟡',
  results[:rescue_partial_raise],
  show_rescue_detail: true
)

print_section(
  'RESCUE AND RAISE — correctly re-raises, Sidekiq retry works as intended',
  '🟢',
  results[:rescue_all_raise],
  show_rescue_detail: false
)

# ── CSV output ────────────────────────────────────────────────────────────────

csv_path = File.join(ROOT, 'sidekiq_error_audit.csv')
File.open(csv_path, 'w') do |f|
  f.puts 'category,job_name,path,rescued_exceptions,any_raise'
  results.each do |category, jobs|
    jobs.each do |job|
      exceptions = job[:rescues].map { |r| r[:exception] }.join(' | ')
      any_raise  = job[:rescues].any? { |r| r[:raises] }
      f.puts [category, job[:name], job[:path], exceptions, any_raise].map { |v| "\"#{v}\"" }.join(',')
    end
  end
end

puts SEPARATOR
puts "  CSV written to: #{csv_path}"
puts SEPARATOR
# rubocop:enable Lint/AmbiguousRange
