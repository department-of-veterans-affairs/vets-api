# frozen_string_literal: true

# Combined script: Get claim IDs and check PDFs
# Usage: rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_from_from526submissions.rb [start_date] [end_date]

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

logger.info "=== VA Form 526 PDF Analysis ==="
logger.info "Date range: #{start_date} to #{end_date}"
logger.info ""

# Step 1: Get claim IDs using the find_submittedClaimIds_from_form526submissions.rb script
logger.info "Step 1: Getting claim IDs from submissions..."
logger.info "Running: rails runner lib/disability_compensation/scripts/pdf_analysis/find_submittedClaimIds_from_form526submissions.rb #{start_date} #{end_date}"

# Run the get_claim_ids script
system("rails runner lib/disability_compensation/scripts/pdf_analysis/find_submittedClaimIds_from_form526submissions.rb #{start_date} #{end_date}")

# Find the most recent claim_ids_export file
export_files = Dir.glob("tmp/script_outputs/claim_ids_export_*.json").sort_by { |f| File.mtime(f) }
if export_files.empty?
  logger.error "ERROR: No claim IDs export file found!"
  exit 1
end

latest_export = export_files.last
logger.info "Using export file: #{latest_export}"

# Parse the JSON export
export_data = JSON.parse(File.read(latest_export))
claim_data = export_data['submissions']

logger.info "Found #{claim_data.count} submissions with claim IDs"
logger.info ""

if claim_data.empty?
  logger.warn "No claim IDs found. Exiting."
  exit 0
end

# Extract unique claim IDs
claim_ids = claim_data.map { |s| s['submitted_claim_id'] }.uniq

# Step 2: Check PDFs using the check_submittedClaimIds_for_pdfs.rb script
logger.info "Step 2: Checking PDFs for claims..."

# Create temporary file with claim IDs
temp_claim_ids_file = "temp_claim_ids_#{Time.now.to_i}.txt"
File.write(temp_claim_ids_file, claim_ids.join("\n"))
logger.info "Created temporary claim IDs file: #{temp_claim_ids_file}"

# Run the check_submittedClaimIds_for_pdfs script
logger.info "Running: rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_for_submittedClaimIds.rb #{temp_claim_ids_file}"
system("rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_for_submittedClaimIds.rb #{temp_claim_ids_file}")

# Find the most recent pdf_check_results file
pdf_result_files = Dir.glob("tmp/script_outputs/pdf_check_results_*.json").sort_by { |f| File.mtime(f) }
if pdf_result_files.empty?
  logger.error "ERROR: No PDF check results file found!"
  # Clean up temp file
  File.delete(temp_claim_ids_file) if File.exist?(temp_claim_ids_file)
  exit 1
end

latest_pdf_results = pdf_result_files.last
logger.info "Using PDF results file: #{latest_pdf_results}"

# Parse the PDF results
pdf_results = JSON.parse(File.read(latest_pdf_results))

# Clean up temporary file
File.delete(temp_claim_ids_file) if File.exist?(temp_claim_ids_file)

logger.info "Found PDF check results for #{pdf_results.count} claims"
logger.info ""
# Summary
has_pdf_count = pdf_results.count { |r| r['has_pdf'] == true }
no_pdf_count = pdf_results.count { |r| r['has_pdf'] == false }
error_count = pdf_results.count { |r| r['error'] }

logger.info "=== SUMMARY ==="
logger.info "Total claims processed: #{pdf_results.count}"
logger.info "Claims with PDF: #{has_pdf_count}"
logger.info "Claims without PDF: #{no_pdf_count}"
logger.info "Errors: #{error_count}"

# Save combined results (merge claim data with PDF results)
combined_results = pdf_results.map do |pdf_result|
  claim_info = claim_data.find { |c| c['submitted_claim_id'] == pdf_result['claim_id'] }
  pdf_result.merge({
    'submission_id' => claim_info ? claim_info['submission_id'] : nil,
    'created_at' => claim_info ? claim_info['created_at'] : nil
  })
end

# Save results
timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
File.write("tmp/script_outputs/combined_check_results_#{timestamp}.json", JSON.pretty_generate(combined_results))
logger.info "\nCombined results saved to: tmp/script_outputs/combined_check_results_#{timestamp}.json"

# Save claim IDs without PDFs
no_pdf_claims = pdf_results.select { |r| r['has_pdf'] == false }.map { |r| r['claim_id'] }
File.write("tmp/script_outputs/claims_no_pdf_#{timestamp}.log", no_pdf_claims.join("\n"))
logger.info "Claim IDs without PDFs saved to: tmp/script_outputs/claims_no_pdf_#{timestamp}.log"