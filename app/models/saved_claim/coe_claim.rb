# frozen_string_literal: true

require 'sentry_logging'

class SavedClaim::CoeClaim < SavedClaim
  include SentryLogging

  FORM = '26-1880'

  def send_to_lgy(edipi:, icn:)
    @edipi = edipi
    @icn = icn
    lgy_service.put_application(payload: prepare_form_data)
    log_message_to_sentry(
      "COE claim submitted to LGY: #{guid}",
      :warn,
      { attachment_id: guid },
      { team: 'vfs-ebenefits' }
    )
    process_attachments!
  end

  def regional_office
    []
  end

  private

  # rubocop:disable Metrics/MethodLength
  def prepare_form_data
    form_copy = {
      'status' => 'SUBMITTED',
      'veteran' => {
        'firstName' => parsed_form['fullName']['firstName'],
        'middleName' => parsed_form['fullName']['middleName'],
        'lastName' => parsed_form['fullName']['lastName'],
        'suffixName' => parsed_form['fullName']['suffixName'],
        'mailingAddress1' => parsed_form['applicantAddress']['street'],
        'mailingAddress2' => parsed_form['applicantAddress']['street2'],
        'mailingCity' => parsed_form['applicantAddress']['city'],
        'mailingState' => parsed_form['applicantAddress']['state'],
        'mailingZip' => parsed_form['applicantAddress']['postalCode'],
        'contactPhone' => parsed_form['contactPhone'],
        'contactEmail' => parsed_form['contactEmail'],
        'vaLoanIndicator' => parsed_form['vaLoanIndicator'],
        # 'vaHomeOwnIndicator' => parsed_form['relevantPriorLoans'][0]['propertyOwned'],
        'vaHomeOwnIndicator' => false,
        'activeDutyIndicator' => false,
        'disabilityIndicator' => false
        # 'identity' => 'VETERAN' # enum: ['VETERAN', 'ADSM', 'NADNA', 'DNANA', 'DRNA']
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
      form_copy['relevantPriorLoans'] << {
        'vaLoanNumber' => loan_info['vaLoanNumber'],
        'startDate' => loan_info['dateRange']['startDate'],
        'paidOffDate' => loan_info['dateRange']['paidOffDate'],
        'loanAmount' => loan_info['loanAmount'],
        'loanEntitlementCharged' => loan_info['loanEntitlementCharged'],
        'propertyOwned' => loan_info['propertyOwned'] || false,
        'oneTimeRestorationRequested' => parsed_form['intent'] == 'ONETIMERESTORATION',
        'irrrlRequested' => parsed_form['intent'] == 'IRRRL',
        'cashoutRefinaceRequested' => parsed_form['intent'] == 'REFI',
        # parsed_form['intent'] == 'INQUIRY'??,
        'homeSellIndicator' => false,
        'noRestorationEntitlementIndicator' => false,
        'propertyAddress1' => loan_info['propertyAddress']['propertyAddress1'],
        'propertyAddress2' => loan_info['propertyAddress']['propertyAddress2'],
        'propertyCity' => loan_info['propertyAddress']['propertyCity'],
        'propertyState' => loan_info['propertyAddress']['propertyState'],
        'propertyCounty' => loan_info['propertyAddress']['propertyCounty'],
        'propertyZip' => loan_info['propertyAddress']['propertyZip'],
        'propertyZipSuffix' => loan_info['propertyAddress']['propertyZipSuffix']
        # 'willRefinance' => loan_info['propertyAddress']['willRefinance']
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

      %w[RESERVE NATIONAL_GUARD].any? do |service_branch|
        next unless military_branch.include?(service_branch)

        index = military_branch.index('_NATIONAL_GUARD') || military_branch.index('_RESERVE')
        military_branch = military_branch[0, index]
        military_branch = 'AIR_FORCE' if military_branch == 'AIR' # Air National Guard is the only one that needs this
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

      if %w[.jpg .jpeg .png .pdf].include? file_extension.downcase
        file_path = Common::FileHelpers.generate_temp_file(attachment.file.read)

        File.rename(file_path, "#{file_path}#{file_extension}")
        file_path = "#{file_path}#{file_extension}"

        document_data = {
          'documentType' => file_extension,
          'description' => parsed_form['fileType'],
          'contentsBase64' => Base64.encode64(File.read(file_path)),
          'fileName' => attachment.file.metadata['filename']
        }

        lgy_service.post_document(payload: document_data)
        Common::FileHelpers.delete_file_if_exists(file_path)
      end
    end
  end
end
