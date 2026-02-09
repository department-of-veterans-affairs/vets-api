# frozen_string_literal: true

# Script to check if a single submitted claim ID has a VA Form 526 PDF
# Usage: rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_for_submittedClaimId.rb <claim_id>

require 'json'
require 'logger'

# Initialize logger
logger = Logger.new($stdout)
logger.level = ENV['LOG_LEVEL'] == 'DEBUG' ? Logger::DEBUG : Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
end

claim_id = ARGV[0]

if claim_id.nil? || claim_id.strip.empty?
  logger.error "Usage: rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_for_submittedClaimId.rb <claim_id>"
  logger.error "Example: rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_for_submittedClaimId.rb ABC123456"
  exit 1
end

claim_id = claim_id.strip
logger.info "Checking PDF for claim: #{claim_id}"

# Find a submission with this claim ID to get ICN
submission = Form526Submission.find_by(submitted_claim_id: claim_id)

if submission.nil?
  result = {
    claim_id: claim_id,
    has_pdf: nil,
    error: 'No submission found for this claim ID'
  }
  puts JSON.pretty_generate(result)
  exit 1
end

icn = submission.account&.icn
if icn.blank?
  result = {
    claim_id: claim_id,
    has_pdf: nil,
    error: 'No ICN found for this submission'
  }
  puts JSON.pretty_generate(result)
  exit 1
end

# Check Lighthouse for PDF
begin
  service = BenefitsClaims::Service.new(icn)
  response = service.get_claim(claim_id)

  response_body = if response.is_a?(String)
                    JSON.parse(response)
                  elsif response.is_a?(Hash)
                    response
                  else
                    raise "Invalid response format"
                  end

  supporting_docs = response_body.dig('data', 'attributes', 'supportingDocuments')

  if supporting_docs.nil?
    result = {
      claim_id: claim_id,
      supporting_documents: [],
      error: nil,
      message: 'No supporting documents found'
    }
  elsif supporting_docs.is_a?(Array)
    # Extract all identifiers from supporting documents
    documents = supporting_docs.map do |doc|
      {
        document_id: doc['documentId'],
        document_type_label: doc['documentTypeLabel'],
        original_file_name: doc['originalFileName'],
        tracked_item_id: doc['trackedItemId'],
        upload_date: doc['uploadDate']
      }
    end

    # Check if VA Form 21-526 PDF exists
    form526_pdf = documents.find do |doc|
      doc[:document_type_label]&.match?(/VA 21-526/i)
    end

    result = {
      claim_id: claim_id,
      supporting_documents: documents,
      has_form526_pdf: form526_pdf.present?,
      form526_document_id: form526_pdf&.dig(:document_id),
      total_documents: documents.count,
      error: nil,
      message: "#{documents.count} supporting documents found#{form526_pdf ? ', including VA Form 21-526 PDF' : ''}"
    }
  else
    result = {
      claim_id: claim_id,
      supporting_documents: [],
      error: 'Invalid supportingDocuments format',
      message: 'API returned unexpected data format'
    }
  end

rescue StandardError => e
  result = {
    claim_id: claim_id,
    has_pdf: nil,
    error: "#{e.class}: #{e.message}",
    message: 'Error checking claim via Lighthouse API'
  }
end

# Output result as JSON
result_json = JSON.pretty_generate(result)

# If called programmatically (by check_pdfs.rb), only write to temp file
if ENV['PDF_CHECK_MODE'] == 'file'
  temp_file = "/tmp/pdf_check_#{claim_id}_#{Time.now.to_i}.json"
  File.write(temp_file, result_json)
  # Don't output anything to stdout in file mode
else
  # Interactive mode - show full output
  puts result_json

  # Also write to a temporary file for reliable parsing
  temp_file = "/tmp/pdf_check_#{claim_id}_#{Time.now.to_i}.json"
  File.write(temp_file, result_json)
  logger.debug "Result also written to: #{temp_file}"
end

# Exit with appropriate code
if result[:has_form526_pdf] == true
  exit 0  # Success - has PDF
elsif result[:has_form526_pdf] == false
  exit 2  # No PDF found
else
  exit 1  # Error occurred
end