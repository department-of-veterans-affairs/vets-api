# frozen_string_literal: true

require 'sentry_logging'

class SavedClaim::CoeClaim < SavedClaim
  include SentryLogging

  FORM = '26-1880'

  def send_to_lgy(edipi:, icn:)
    @edipi = edipi
    @icn = icn

    if @edipi.blank?
      log_message_to_sentry(
        'COE application cannot be submitted without an edipi!',
        :error,
        {},
        { team: 'vfs-ebenefits' }
      )
    end

    response = lgy_service.put_application(payload: prepare_form_data)
    log_message_to_sentry(
      "COE claim submitted to LGY: #{guid}",
      :warn,
      { attachment_id: guid },
      { team: 'vfs-ebenefits' }
    )
    process_attachments!
    response['reference_number']
  end

  def regional_office
    []
  end

  private

  # rubocop:disable Metrics/MethodLength
  def prepare_form_data
    postal_code, postal_code_suffix = parsed_form['applicantAddress']['postalCode'].split('-', 2)
    form_copy = {
      'status' => 'SUBMITTED',
      'veteran' => {
        'firstName' => parsed_form['fullName']['first'],
        'middleName' => parsed_form['fullName']['middle'] || '',
        'lastName' => parsed_form['fullName']['last'],
        'suffixName' => parsed_form['fullName']['suffix'] || '',
        'dateOfBirth' => parsed_form['dateOfBirth'],
        'vetAddress1' => parsed_form['applicantAddress']['street'],
        'vetAddress2' => parsed_form['applicantAddress']['street2'] || '',
        'vetCity' => parsed_form['applicantAddress']['city'],
        'vetState' => parsed_form['applicantAddress']['state'],
        'vetZip' => postal_code,
        'vetZipSuffix' => postal_code_suffix,
        'mailingAddress1' => parsed_form['applicantAddress']['street'],
        'mailingAddress2' => parsed_form['applicantAddress']['street2'] || '',
        'mailingCity' => parsed_form['applicantAddress']['city'],
        'mailingState' => parsed_form['applicantAddress']['state'],
        'mailingZip' => postal_code,
        'mailingZipSuffix' => postal_code_suffix || '',
        'contactPhone' => parsed_form['contactPhone'],
        'contactEmail' => parsed_form['contactEmail'],
        'vaLoanIndicator' => parsed_form['vaLoanIndicator'],
        'vaHomeOwnIndicator' => (parsed_form['relevantPriorLoans'] || []).any? { |obj| obj['propertyOwned'] },
        # parsed_form['identity'] can be: 'VETERAN', 'ADSM', 'NADNA', 'DNANA', or 'DRNA'.
        'activeDutyIndicator' => parsed_form['identity'] == 'ADSM',
        'disabilityIndicator' => false
      },
      'relevantPriorLoans' => [],
      'periodsOfService' => []
    }
    relevant_prior_loans(form_copy) if parsed_form.key?('relevantPriorLoans')
    periods_of_service(form_copy) if parsed_form.key?('periodsOfService')

    update(form: form_copy.to_json)
    form_copy
  end
  # rubocop:enable Metrics/MethodLength

  def lgy_service
    @lgy_service ||= LGY::Service.new(edipi: @edipi, icn: @icn)
  end

  # rubocop:disable Metrics/MethodLength
  def relevant_prior_loans(form_copy)
    parsed_form['relevantPriorLoans'].each do |loan_info|
      property_zip, property_zip_suffix = loan_info['propertyAddress']['propertyZip'].split('-', 2)
      form_copy['relevantPriorLoans'] << {
        'vaLoanNumber' => loan_info['vaLoanNumber'].to_s,
        'startDate' => loan_info['dateRange']['from'],
        'paidOffDate' => loan_info['dateRange']['to'],
        'loanAmount' => loan_info['loanAmount'],
        'loanEntitlementCharged' => loan_info['loanEntitlementCharged'],
        # propertyOwned also maps to the the stillOwn indicator on the LGY side
        'propertyOwned' => loan_info['propertyOwned'] || false,
        # In UI: "A one-time restoration of entitlement"
        # In LGY: "One Time Resto"
        'oneTimeRestorationRequested' => loan_info['intent'] == 'ONETIMERESTORATION',
        # In UI: "An Interest Rate Reduction Refinance Loan (IRRRL) to refinance the balance of a current VA home loan"
        # In LGY: "IRRRL Ind"
        'irrrlRequested' => loan_info['intent'] == 'IRRRL',
        # In UI: "A regular cash-out refinance of a current VA home loan"
        # In LGY: "Cash Out Refi"
        'cashoutRefinaceRequested' => loan_info['intent'] == 'REFI',
        # In UI: "An entitlement inquiry only"
        # In LGY: "Entitlement Inquiry Only"
        'noRestorationEntitlementIndicator' => loan_info['intent'] == 'INQUIRY',
        # LGY has requested `homeSellIndicator` always be null
        'homeSellIndicator' => nil,
        'propertyAddress1' => loan_info['propertyAddress']['propertyAddress1'],
        'propertyAddress2' => loan_info['propertyAddress']['propertyAddress2'] || '',
        'propertyCity' => loan_info['propertyAddress']['propertyCity'],
        'propertyState' => loan_info['propertyAddress']['propertyState'],
        # confirmed OK to omit propertyCounty, but LGY still requires a string
        'propertyCounty' => '',
        'propertyZip' => property_zip,
        'propertyZipSuffix' => property_zip_suffix || ''
      }
    end
  end
  # rubocop:enable Metrics/MethodLength

  def periods_of_service(form_copy)
    parsed_form['periodsOfService'].each do |service_info|
      # values from the FE for military_branch are:
      # ["Air Force", "Air Force Reserve", "Air National Guard", "Army", "Army National Guard", "Army Reserve",
      # "Coast Guard", "Coast Guard Reserve", "Marine Corps", "Marine Corps Reserve", "Navy", "Navy Reserve"]
      # these need to be formatted because LGY only accepts [ARMY, NAVY, MARINES, AIR_FORCE, COAST_GUARD, OTHER]
      # and then we have to pass in ACTIVE_DUTY or RESERVE_NATIONAL_GUARD for service_type
      military_branch = service_info['serviceBranch'].parameterize.underscore.upcase
      service_type = 'ACTIVE_DUTY'

      # "Marine Corps" must be converted to "Marines" here, so that the `.any`
      # block below can convert "Marine Corps" and "Marine Corps Reserve" to
      # "MARINES", to meet LGY's requirements.
      military_branch = military_branch.gsub('MARINE_CORPS', 'MARINES')

      %w[RESERVE NATIONAL_GUARD].any? do |service_branch|
        next unless military_branch.include?(service_branch)

        index = military_branch.index('_NATIONAL_GUARD') || military_branch.index('_RESERVE')
        military_branch = military_branch[0, index]
        # "Air National Guard", unlike "Air Force Reserve", needs to be manually
        # transformed to AIR_FORCE here, to meet LGY's requirements.
        military_branch = 'AIR_FORCE' if military_branch == 'AIR'
        service_type = 'RESERVE_NATIONAL_GUARD'
      end

      form_copy['periodsOfService'] << {
        'enteredOnDuty' => service_info['dateRange']['from'],
        'releasedActiveDuty' => service_info['dateRange']['to'],
        'militaryBranch' => military_branch,
        'serviceType' => service_type,
        'disabilityIndicator' => false
      }
    end
  end

  def process_attachments!
    supporting_documents = parsed_form['files']
    if supporting_documents.present?
      files = PersistentAttachment.where(guid: supporting_documents.map { |doc| doc['confirmationCode'] })
      files.find_each { |f| f.update(saved_claim_id: id) }

      prepare_document_data
    end
  end

  def prepare_document_data
    persistent_attachments.each do |attachment|
      file_extension = File.extname(URI.parse(attachment.file.url).path)
      claim_file_data =
        parsed_form['files'].find { |f| f['confirmationCode'] == attachment['guid'] } ||
        { 'attachmentType' => '', 'attachmentDescription' => '' }

      if %w[.jpg .jpeg .png .pdf].include? file_extension.downcase
        file_path = Common::FileHelpers.generate_temp_file(attachment.file.read)

        File.rename(file_path, "#{file_path}#{file_extension}")
        file_path = "#{file_path}#{file_extension}"

        document_data = {
          # This is one of the options in the "Document Type" dropdown on the
          # "Your supporting documents" step of the COE form. E.g. "Discharge or
          # separation papers (DD214)"
          'documentType' => claim_file_data['attachmentType'],
          # This is the vet's own description of a document, after selecting
          # "other" as the `attachmentType`.
          'description' => claim_file_data['attachmentDescription'],
          'contentsBase64' => Base64.encode64(File.read(file_path)),
          'fileName' => attachment.file.metadata['filename']
        }

        lgy_service.post_document(payload: document_data)
        Common::FileHelpers.delete_file_if_exists(file_path)
      end
    end
  end
end
