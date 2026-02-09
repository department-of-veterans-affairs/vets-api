# frozen_string_literal: true

# Simple script to check PDFs for claims
# Usage: rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_for_submittedClaimIds.rb [claim_ids_file]

require 'json'
require 'logger'

# Initialize logger
logger = Logger.new($stdout)
logger.level = ENV['LOG_LEVEL'] == 'DEBUG' ? Logger::DEBUG : Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
end

claim_ids_file = ARGV[0]

if claim_ids_file.nil?
  logger.error "Usage: rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_for_submittedClaimIds.rb <claim_ids_file>"
  logger.error "Example: rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_for_submittedClaimIds.rb claim_ids.txt"
  exit 1
end

unless File.exist?(claim_ids_file)
  logger.error "File not found: #{claim_ids_file}"
  exit 1
end

claim_ids = File.readlines(claim_ids_file).map(&:strip).reject(&:empty?)

logger.info "Checking PDFs for #{claim_ids.count} claims"

results = []
claim_ids.each_with_index do |claim_id, index|
  print "Processing #{index + 1}/#{claim_ids.count}: #{claim_id}... "

  # Use the check_submittedClaimsId_for_pdfs script
  # Run the script and wait a moment for the file to be created
  system("PDF_CHECK_MODE=file rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_for_submittedClaimId.rb \"#{claim_id}\" >/dev/null 2>&1")
  sleep(0.1)  # Give a moment for the file to be written

  # Look for the temp file (most recent one for this claim_id)
  temp_files = Dir.glob("/tmp/pdf_check_#{claim_id}_*.json").sort_by { |f| File.mtime(f) }
  temp_file_path = temp_files.last

  if temp_file_path.nil? || !File.exist?(temp_file_path)
    logger.error "ERROR: Result file not found"
    results << {
      'claim_id' => claim_id,
      'has_pdf' => nil,
      'form526_document_id' => nil,
      'supporting_documents' => [],
      'total_documents' => 0,
      'error' => 'Result file not created by script'
    }
    next
  end

  begin
    result = JSON.parse(File.read(temp_file_path))

    # Clean up temp file
    File.delete(temp_file_path)

    # Convert snake_case keys to match expected format
    formatted_result = {
      'claim_id' => result['claim_id'],
      'has_pdf' => result['has_form526_pdf'],
      'form526_document_id' => result['form526_document_id'],
      'supporting_documents' => result['supporting_documents'],
      'total_documents' => result['total_documents'],
      'error' => result['error']
    }

    case result['has_form526_pdf']
    when true
      logger.info "HAS PDF"
    when false
      logger.info "NO PDF"
    else
      logger.error "ERROR"
    end

    results << formatted_result

  rescue JSON::ParserError => e
    logger.error "ERROR: Failed to parse result file"
    File.delete(temp_file_path) if File.exist?(temp_file_path)
    results << {
      'claim_id' => claim_id,
      'has_pdf' => nil,
      'form526_document_id' => nil,
      'supporting_documents' => [],
      'total_documents' => 0,
      'error' => "Failed to parse result file: #{e.message}"
    }
  end
end

# Summary
has_pdf_count = results.count { |r| r['has_pdf'] == true }
no_pdf_count = results.count { |r| r['has_pdf'] == false }
error_count = results.count { |r| r['error'] }

logger.info "\nSummary:"
logger.info "  Total claims: #{results.count}"
logger.info "  Has PDF: #{has_pdf_count}"
logger.info "  No PDF: #{no_pdf_count}"
logger.info "  Errors: #{error_count}"

# Save results
timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
File.write("tmp/script_outputs/pdf_check_results_#{timestamp}.json", JSON.pretty_generate(results))
logger.info "\nResults saved to: pdf_check_results_#{timestamp}.json"