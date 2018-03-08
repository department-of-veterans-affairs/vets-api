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

    metadata = generate_metadata
    binding.pry; fail
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
    binding.pry; fail

    metadata = {
      'veteranFirstName' => form['veteranFirstName'],
      'veteranLastName' => form['veteranLastName'],
      'fileNumber' => form['vaFileNumber'],
      'receiveDt' => @claim.created_at.strftime('%Y-%m-%d %H:%M:%S'),
      'zipCode' => form['claimantAddress'].try(:[], 'postalCode'),
      'uuid' => @claim.guid,
      'source' => 'vets.gov',
      'hashV' => form_pdf_metadata[:hash],
      'numberAttachments' => @claim.persistent_attachments.count,
      'docType' => nil,
      'numberPages' => form_pdf_metadata[:pages]
    }

    attachments = claim.persistent_attachments
    attachments.each_with_index do |_attachment, index|
      n = index + 1

      metadata["ahash#{n}"] = nil # TODO: SHA-256 hash of attachment
      metadata["numberPages#{n}"] = nil # TODO: number of pages for each attachment
    end

    metadata
  end
end
