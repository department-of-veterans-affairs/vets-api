# frozen_string_literal: true

class SubmitSavedClaimJob
  include Sidekiq::Worker

  def perform(saved_claim_id)
    @claim = SavedClaim.find(saved_claim_id)
    @submission = {
      'document' => process_record(@claim)
    }

    @claim.persistent_attachments.each_with_index do |record, i|
      key = "attachment#{i + 1}"
      @submission[key] = process_record(record)
    end

    @submission['metadata'] = generate_metadata.to_json
  end

  def process_record(record)
    pdf_path = record.to_pdf
    stamped_path1 = PensionBurial::DatestampPdf.new(pdf_path).run(text: 'VETS.GOV', x: 5, y: 5)
    PensionBurial::DatestampPdf.new(stamped_path1).run(
      text: 'FDC Reviewed - Vets.gov Submission',
      x: 429,
      y: 770,
      text_only: true
    )
  end

  def get_hash_and_pages(file_path)
    {
      hash: Digest::SHA256.file(file_path).hexdigest,
      pages: PDF::Reader.new(file_path).pages.size
    }
  end

  def generate_metadata
    form = @claim.parsed_form
    form_pdf_metadata = get_hash_and_pages(@submission['document'])
    number_attachments = @claim.persistent_attachments.count
    veteran_full_name = form['veteranFullName']

    metadata = {
      # TODO check if these are required
      'veteranFirstName' => veteran_full_name['first'],
      'veteranLastName' => veteran_full_name['last'],
      'fileNumber' => form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
      'receiveDt' => @claim.created_at.strftime('%Y-%m-%d %H:%M:%S'),
      # TODO check if this is required
      'zipCode' => form['claimantAddress'].try(:[], 'postalCode'),
      'uuid' => @claim.guid,
      'source' => 'CSRA-V',
      'hashV' => form_pdf_metadata[:hash],
      'numberAttachments' => number_attachments,
      'docType' => @claim.form_id,
      'numberPages' => form_pdf_metadata[:pages]
    }

    number_attachments.times do |i|
      j = i + 1
      submission_key = "attachment#{i + 1}"
      attachment_pdf_metadata = get_hash_and_pages(@submission[submission_key])
      metadata["ahash#{j}"] = attachment_pdf_metadata[:hash]
      metadata["numberPages#{j}"] = attachment_pdf_metadata[:pages]
    end

    metadata
  end
end
