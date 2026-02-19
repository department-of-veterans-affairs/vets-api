#!/usr/bin/env ruby
# frozen_string_literal: true

# Add a form to the VA Form Upload Tool backend (vets-api)
#
# Usage:
#   ruby scripts/add-form-upload.rb --form-id=21-4170 [--max-pages=4] [--min-pages=1] [--stamp] [--stamp-page=0]
#
# Run from the vets-api repository root.

require 'optparse'

options = {
  max_pages: 10,
  min_pages: 1,
  stamp: false,
  stamp_page: nil,
  title: nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on('--form-id=ID', 'Form ID (e.g., 21-4170)') { |v| options[:form_id] = v }
  opts.on('--title=TITLE', 'Form title for Datadog widget') { |v| options[:title] = v }
  opts.on('--max-pages=N', Integer, 'Maximum expected pages (default: 10)') { |v| options[:max_pages] = v }
  opts.on('--min-pages=N', Integer, 'Minimum expected pages (default: 1)') { |v| options[:min_pages] = v }
  opts.on('--stamp', 'Add timestamp stamp to form') { options[:stamp] = true }
  opts.on('--stamp-page=N', Integer, 'Page for stamp, 0-indexed (default: 0)') { |v| options[:stamp_page] = v }
end.parse!

unless options[:form_id]
  puts 'Error: --form-id is required'
  exit 1
end

FORM_ID = options[:form_id].upcase
FORM_ID_UPLOAD = "#{FORM_ID}-UPLOAD"

puts "Adding form #{FORM_ID} to vets-api..."
puts ''

# Helper to safely modify a file
def modify_file(path, description)
  unless File.exist?(path)
    puts "  [WARN] #{path} not found - skipping"
    return
  end

  content = File.read(path)
  original = content.dup

  yield content

  if content == original
    puts "  [SKIP] #{description} - already present"
  else
    File.write(path, content)
    puts "  [DONE] #{description}"
  end
end

# === 1. form_profile.rb: ALL_FORMS[:form_upload] array ===
modify_file('app/models/form_profile.rb', 'form_profile.rb - ALL_FORMS[:form_upload]') do |content|
  next if content.include?("#{FORM_ID_UPLOAD}")

  # Add to form_upload array
  content.gsub!(/(form_upload: %w\[\n)((?:\s+[\w-]+-UPLOAD\n)+)(\s*\],)/) do
    "#{Regexp.last_match(1)}#{Regexp.last_match(2)}      #{FORM_ID_UPLOAD}\n#{Regexp.last_match(3)}"
  end
end

# === 2. form_profile.rb: FORM_ID_TO_CLASS hash ===
modify_file('app/models/form_profile.rb', 'form_profile.rb - FORM_ID_TO_CLASS') do |content|
  next if content.include?("'#{FORM_ID_UPLOAD}' =>")

  # Find the }.freeze that closes FORM_ID_TO_CLASS and insert before it
  # Look for the last entry before }.freeze (handles both with and without trailing comma)
  pattern = /(    '[^']+' => [^\n]+)(,?\n  \}.freeze)/
  
  if content =~ pattern
    content.gsub!(pattern) do
      last_entry = Regexp.last_match(1)
      closing = Regexp.last_match(2)
      # Ensure last existing entry has comma, add new entry without trailing comma
      last_entry_with_comma = last_entry.end_with?(',') ? last_entry : "#{last_entry},"
      "#{last_entry_with_comma}\n    '#{FORM_ID_UPLOAD}' => ::FormProfiles::FormUpload\n  }.freeze"
    end
  end
end

# === 3. va_form.rb: CONFIGS hash (page limits) ===
modify_file('app/models/persistent_attachments/va_form.rb', "va_form.rb - CONFIGS (max: #{options[:max_pages]}, min: #{options[:min_pages]})") do |content|
  next if content.include?("'#{FORM_ID}'")

  # Find the last entry (with or without trailing comma) before closing
  if content =~ /(      '[\w-]+' => \{ max_pages: \d+, min_pages: \d+ \}),?\n(\s+\}\n\s+\))/
    content.gsub!(/(      '[\w-]+' => \{ max_pages: \d+, min_pages: \d+ \}),?\n(\s+\}\n\s+\))/) do
      "#{Regexp.last_match(1)},\n      '#{FORM_ID}' => { max_pages: #{options[:max_pages]}, min_pages: #{options[:min_pages]} }\n#{Regexp.last_match(2)}"
    end
  end
end

# === 4. form_upload_email.rb: SUPPORTED_FORMS array (VANotify) ===
modify_file('modules/simple_forms_api/app/services/simple_forms_api/notification/form_upload_email.rb', 'form_upload_email.rb - SUPPORTED_FORMS (VANotify)') do |content|
  next if content.include?(FORM_ID)

  content.gsub!(/(SUPPORTED_FORMS = %w\[\n)((?:\s+[\w-]+\n)+)(\s*\].freeze)/) do
    "#{Regexp.last_match(1)}#{Regexp.last_match(2)}        #{FORM_ID}\n#{Regexp.last_match(3)}"
  end
end

# === 5. scanned_form_stamps.rb: FORMS_WITH_STAMPS (if --stamp) ===
if options[:stamp]
  modify_file('modules/simple_forms_api/app/services/simple_forms_api/scanned_form_stamps.rb', 'scanned_form_stamps.rb - FORMS_WITH_STAMPS') do |content|
    next if content.include?(FORM_ID)

    content.gsub!(/(FORMS_WITH_STAMPS = %w\[\n)((?:\s+[\w-]+\n)+)(\s*\].freeze)/) do
      "#{Regexp.last_match(1)}#{Regexp.last_match(2)}      #{FORM_ID}\n#{Regexp.last_match(3)}"
    end
  end

  # Add stamp page override if not page 0
  if options[:stamp_page] && options[:stamp_page] != 0
    modify_file('modules/simple_forms_api/app/services/simple_forms_api/scanned_form_stamps.rb', "scanned_form_stamps.rb - STAMP_PAGE_OVERRIDES (page #{options[:stamp_page]})") do |content|
      next if content.include?("'#{FORM_ID}' =>")

      content.gsub!(/(STAMP_PAGE_OVERRIDES = \{\n)((?:\s+'[\w-]+' => \d+,?[^\n]*\n)+)(\s*\}.freeze)/) do
        "#{Regexp.last_match(1)}#{Regexp.last_match(2)}      '#{FORM_ID}' => #{options[:stamp_page]},\n#{Regexp.last_match(3)}"
      end
    end
  end
else
  puts '  [SKIP] No stamp requested'
end

puts ''
puts "✅ Backend setup complete for #{FORM_ID}"
puts ''
puts 'Next steps:'
puts "  1. Run frontend: node script/add-form-upload-form.js --formId=#{FORM_ID}"
puts "  2. Test at: localhost:3001/forms/upload/#{FORM_ID.downcase}/introduction"
puts ''
puts '═' * 60
puts '📊 ADD THIS TO DATADOG DASHBOARD'
puts '═' * 60
puts ''
puts 'Dashboard: https://vagov.ddog-gov.com/dashboard/zsa-kgr-gvy/form-upload'
puts ''
puts 'Widget JSON:'
puts '-' * 60

widget_json = {
  "definition" => {
    "title" => "#{FORM_ID}: #{options[:title] || 'Form Title Here'}",
    "title_size" => "16",
    "title_align" => "left",
    "requests" => [
      {
        "response_format" => "scalar",
        "queries" => [
          {
            "name" => "a",
            "data_source" => "logs",
            "search" => {
              "query" => "@payload.form_id:#{FORM_ID} env:eks-prod"
            },
            "indexes" => ["*"],
            "group_by" => [
              {
                "facet" => "@payload.result",
                "limit" => 10,
                "sort" => {
                  "aggregation" => "count",
                  "order" => "desc"
                },
                "should_exclude_missing" => true
              }
            ],
            "compute" => {
              "aggregation" => "count"
            },
            "storage" => "flex_tier"
          }
        ],
        "formulas" => [
          {
            "formula" => "a"
          }
        ],
        "sort" => {
          "count" => 10,
          "order_by" => [
            {
              "type" => "formula",
              "index" => 0,
              "order" => "desc"
            }
          ]
        }
      }
    ],
    "type" => "sunburst",
    "legend" => {
      "type" => "table"
    }
  },
  "layout" => {
    "x" => 0,
    "y" => 0,
    "width" => 3,
    "height" => 3
  }
}

require 'json'
puts JSON.pretty_generate(widget_json)
puts '-' * 60
