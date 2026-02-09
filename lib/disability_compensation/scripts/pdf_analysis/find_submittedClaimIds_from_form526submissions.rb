# frozen_string_literal: true

# Script to analyze Form526Submission records for submitted_claim_id presence and extract claim IDs
# Usage: rails runner lib/disability_compensation/scripts/pdf_analysis/find_submittedClaimIds_from_form526submissions.rb [start_date] [end_date]

require 'json'
require 'logger'

# Initialize logger
logger = Logger.new($stdout)
logger.level = ENV['LOG_LEVEL'] == 'DEBUG' ? Logger::DEBUG : Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
end

start_date = ARGV[0] || (Date.today - 7).to_s
end_date = ARGV[1] || Date.today.to_s

start_date = Date.parse(start_date)
end_date = Date.parse(end_date)

logger.info "Analyzing Form526Submission records for submitted_claim_id"
logger.info "Date range: #{start_date} to #{end_date}"
logger.info "=" * 60

# Get all submissions in date range
all_submissions = Form526Submission
  .where('created_at >= ? AND created_at <= ?', start_date, end_date)
  .order(:created_at)

total_count = all_submissions.count
logger.info "Total submissions found: #{total_count}"

if total_count == 0
  logger.warn "No submissions found in the specified date range."
  exit
end

# Check for submitted_claim_id presence
with_claim_id = all_submissions.where.not(submitted_claim_id: nil)
without_claim_id = all_submissions.where(submitted_claim_id: nil)

with_count = with_claim_id.count
without_count = without_claim_id.count

logger.info ""
logger.info "Results:"
logger.info "  Submissions WITH submitted_claim_id: #{with_count} (#{(with_count.to_f / total_count * 100).round(1)}%)"
logger.info "  Submissions WITHOUT submitted_claim_id: #{without_count} (#{(without_count.to_f / total_count * 100).round(1)}%)"

# Show some examples
logger.info ""
logger.info "Sample submissions WITH claim IDs:"
with_claim_id.limit(5).each do |sub|
  logger.debug "  ID: #{sub.id}, Claim ID: #{sub.submitted_claim_id}, Created: #{sub.created_at.strftime('%Y-%m-%d %H:%M')}"
end

if without_count > 0
  logger.info ""
  logger.info "Sample submissions WITHOUT claim IDs:"
  without_claim_id.limit(5).each do |sub|
    logger.debug "  ID: #{sub.id}, Created: #{sub.created_at.strftime('%Y-%m-%d %H:%M')}"
  end
end

# Extract claim IDs if any exist
if with_count > 0
  logger.info ""
  logger.info "Extracting claim IDs from #{with_count} submissions..."

  # Prepare data for export
  export_data = with_claim_id.map do |sub|
    {
      submission_id: sub.id,
      submitted_claim_id: sub.submitted_claim_id,
      created_at: sub.created_at.iso8601
    }
  end

  # Save to JSON file
  timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  filename = "tmp/script_outputs/claim_ids_export_#{timestamp}.json"

  File.open(filename, 'w') do |f|
    f.write(JSON.pretty_generate({
      metadata: {
        date_range: "#{start_date} to #{end_date}",
        total_submissions: total_count,
        submissions_with_claim_ids: with_count,
        submissions_without_claim_ids: without_count,
        generated_at: Time.now.iso8601
      },
      submissions: export_data
    }))
  end

  logger.info "Claim IDs exported to: #{filename}"

  # Also print summary to console
  logger.info "\nFirst 10 submissions with claim IDs:"
  export_data.first(10).each do |data|
    logger.info "  Submission ID: #{data[:submission_id]}, Claim ID: #{data[:submitted_claim_id]}, Created: #{data[:created_at]}"
  end

  if with_count > 10
    logger.info "... and #{with_count - 10} more"
  end
end

# Save detailed results if there are issues
if without_count > 0
  logger.info ""
  logger.info "Found #{without_count} submissions without claim IDs"

  # Save list of submissions without claim IDs
  timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  filename = "tmp/script_outputs/submissions_no_claim_id_#{timestamp}.log"

  File.open(filename, 'w') do |f|
    f.puts "# Form526Submission records without submitted_claim_id"
    f.puts "# Generated: #{Time.now}"
    f.puts "# Date range: #{start_date} to #{end_date}"
    f.puts "# Total without claim ID: #{without_count}"
    f.puts

    without_claim_id.each do |sub|
      f.puts "#{sub.id},#{sub.created_at.iso8601}"
    end
  end

  logger.info "List saved to: #{filename}"
end

logger.info ""
logger.info "Analysis complete!"