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
    # process_attachments!
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
      form_copy['periodsOfService'] << {
        'enteredOnDuty' => service_info['dateRange']['from'],
        'releasedActiveDuty' => service_info['dateRange']['to'],
        'militaryBranch' => service_info['militaryBranch'].parameterize.underscore.upcase,
        'disabilityIndicator' => false
      }
    end
  end
end
