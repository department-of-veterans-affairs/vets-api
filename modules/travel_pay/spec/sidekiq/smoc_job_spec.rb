# frozen_string_literal: true

describe TravelPay::SMOCJob, type: :worker do
  it 'sends notification with success template' do
    worker = described_class.new
    notify_client = double

    expect(VaNotify::Service).to receive(:new).with(Settings.services.va_gov.api_key)
                                              .and_return(notify_client)
    expect(notify_client).to receive(:send_email).with(
      {
        recipient_identifier: { id_value: '<<<<ICN>>>>', id_type: 'ICN' },
        ### FIX SOME_TEMPLATE_NAME WITH REAL TEMPLATE
        # ON NETWORK, VISIT: staging.notifications.va.gov
        # SIGN IN WITH PIV
        # NAV TO 'Workspace'
        # SEARCH 'SMOC'
        # VIEW/EDIT TEMPLATE
        template_id: Settings.vanotify.services.va_gov.template_id.some_template_name
      }
    )
    expect(worker).not_to receive(:log_exception_to_sentry)

    VCR.use_cassette('travel_pay/submit/success', match_requests_on: [:host]) do
      worker.perform('<<<<SOME_USER>>>>', appt_datetime)
    end

    expect(StatsD).to have_received(:increment).with(@statsd_success).exactly(1).time
  end
end
