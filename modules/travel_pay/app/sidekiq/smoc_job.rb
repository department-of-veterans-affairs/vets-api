require 'sidekiq'
require 'sidekiq/monitored_worker'

module TravelPay
  class SMOCJob
    include Sidekiq::Job
    include Sidekiq::MonitoredWorker

    def perform(icn, appt_datetime)
      Rails.logger.info(message: 'SMOC transaction START')

      appt_id = get_appt_or_raise(appt_datetime)
      claim_id = get_claim_id(appt_id)

      Rails.logger.info(message: "SMOC transaction: Add expense to claim #{claim_id.slice(0, 8)}")
      @expense_service.add_expense({ 'claim_id' => claim_id, 'appt_date' => appt_datetime })

      Rails.logger.info(message: "SMOC transaction: Submit claim #{claim_id.slice(0, 8)}")
      @claims_service.submit_claim(claim_id)

      Rails.logger.info(message: 'SMOC transaction END')
    rescue e
      Rails.logger.error(message: e.message)
      # VANotify notify modules/va_notify/README.md
      notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
      notify_client.send_email({
                                 recipient_identifier: { id_value: icn, id_type: 'ICN' },
                                 template_id: Settings.vanotify.services.va_gov.template_id.form10_3542_smoc_failure_email
                               })
    end

    private

    def get_appt_or_raise(appt_datetime)
      appt_not_found_msg = "No appointment found for #{appt_datetime}"

      Rails.logger.info(message: "SMOC transaction: Get appt by date time: #{appt_datetime}")
      appt = @appts_service.get_appointment_by_date_time({ 'appt_datetime' => appt_datetime })

      if appt[:data].nil?
        Rails.logger.error(message: appt_not_found_msg)
        raise Common::Exceptions::ResourceNotFound, detail: appt_not_found_msg
      end

      appt[:data]['id']
    end

    def get_claim_id(appt_id)
      Rails.logger.info(message: 'SMOC transaction: Create claim')
      claim = @claims_service.create_new_claim({ 'btsss_appt_id' => appt_id })

      claim['claimId']
    end
  end
end
