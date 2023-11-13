# frozen_string_literal: true

require 'benefits_intake_service/service'
require 'central_mail/datestamp_pdf'

class Lighthouse::PensionBenefitIntakeJob
  include Sidekiq::Job

  class PensionBenefitIntakeError < StandardError; end

  # retry for one day
  sidekiq_options retry: 14, queue: 'low'
  # Set minimum retry time to ~1 hour
  sidekiq_retry_in do |count, _exception|
    rand(3600..3660) if count < 9
  end

  def perform(saved_claim_id)
    @claim = SavedClaim::Pension.find(saved_claim_id)
    @form_path = process_pdf(claim.to_pdf)
    @attachment_paths = claim.persistent_attachments.map { |pa| process_pdf(pa.to_pdf) }
    Rails.logger.info({ message: 'PensionBenefitIntakeJob Initiate Attempt', claim_id: claim.id })

    lighthouse_service = BenefitsIntakeService::Service.new(with_upload_location: true)
    Rails.logger.info({ message: 'PensionBenefitIntakeJob Attempt', claim_id: claim.id, uuid: lighthouse_service.uuid})

    response = lighthouse_service.upload_form(
      main_document: split_file_and_path(form_path),
      attachments: attachment_paths.map(&method(:split_file_and_path)),
      form_metadata: generate_metadata_lh
    )
    Rails.logger.info({ message: 'PensionBenefitIntakeJob Complete', claim_id: claim.id, uuid: lighthouse_service.uuid})

    check_success(result, saved_claim_id, user_struct)
  rescue => e
    Rails.logger.warn('Lighthouse::PensionBenefitIntakeJob failed!',
                      { user_uuid: user_struct['uuid'], saved_claim_id:, icn: user_struct['icn'], error: e.message })
    raise
  ensure
    cleanup_file_paths
  end

  def process_pdf(pdf_path)
    stamped_path = CentralMail::DatestampPdf.new(pdf_path).run(text: 'VA.GOV', x: 5, y: 5)
    CentralMail::DatestampPdf.new(stamped_path).run(
      text: 'FDC Reviewed - va.gov Submission',
      x: 429,
      y: 770,
      text_only: true
    )
  end

  def split_file_and_path(path)
    { file: path, file_name: path.split('/').last }
  end

  def generate_metadata_lh
    form = claim.parsed_form
    address = form['veteran_contact_information']['veteran_address']
    {
      veteran_first_name: form['veteran_information']['full_name']['first'],
      veteran_last_name: form['veteran_information']['full_name']['last'],
      file_number: form['veteran_information']['file_number'] || form['veteran_information']['ssn'],
      zip: address['country'] == 'USA' ? address['postalCode'] : FOREIGN_POSTALCODE,
      doc_type: claim.form_id,
      claim_date: claim.created_at
    }
  end

  def check_success(response, saved_claim_id)
    if response.success?
      Rails.logger.info('Lighthouse::PensionBenefitIntakeJob Succeeded!', { saved_claim_id: })
      claim.send_confirmation_email(OpenStruct.new(user_struct))
    else
      Rails.logger.info('Lighthouse::PensionBenefitIntakeJob Unsuccessful',
                        { response: response['message'].presence || response['errors'] })
      raise PensionBenefitIntakeError, response.to_s
    end
  end

  def cleanup_file_paths
    Common::FileHelpers.delete_file_if_exists(form_path)
    attachment_paths.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
  end

end
