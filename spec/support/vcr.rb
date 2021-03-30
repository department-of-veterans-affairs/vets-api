# frozen_string_literal: true

# shared betw rails_helper and pact_helper
VCR.configure do |c|
  c.cassette_library_dir = 'spec/support/vcr_cassettes'
  c.hook_into :webmock
  # experiencing VCR-induced frustation? uncomment this:
  # c.debug_logger = File.open('vcr.log', 'w')

  c.filter_sensitive_data('<APP_TOKEN>') { Settings.mhv.rx.app_token }
  c.filter_sensitive_data('<AV_KEY>') { Settings.vet360.address_validation.api_key }
  c.filter_sensitive_data('<EE_PASS>') { Settings.hca.ee.pass }
  c.filter_sensitive_data('<EVSS_AWS_BASE_URL>') { Settings.evss.aws.url }
  c.filter_sensitive_data('<EVSS_BASE_URL>') { Settings.evss.url }
  c.filter_sensitive_data('<GIDS_URL>') { Settings.gids.url }
  c.filter_sensitive_data('<LIGHTHOUSE_API_KEY>') { Settings.lighthouse.facilities.api_key }
  c.filter_sensitive_data('<MDOT_KEY>') { Settings.mdot.api_key }
  c.filter_sensitive_data('<MHV_HOST>') { Settings.mhv.rx.host }
  c.filter_sensitive_data('<MHV_SM_APP_TOKEN>') { Settings.mhv.sm.app_token }
  c.filter_sensitive_data('<MHV_SM_HOST>') { Settings.mhv.sm.host }
  c.filter_sensitive_data('<MPI_URL>') { Settings.mvi.url }
  c.filter_sensitive_data('<OKTA_TOKEN>') { Settings.oidc.base_api_token }
  c.filter_sensitive_data('<PD_TOKEN>') { Settings.maintenance.pagerduty_api_token }
  c.filter_sensitive_data('<PENSIONS_TOKEN>') { Settings.central_mail.upload.token }
  c.filter_sensitive_data('<PRENEEDS_HOST>') { Settings.preneeds.host }
  c.filter_sensitive_data('<DMC_TOKEN>') { Settings.dmc.client_secret }

  c.before_record do |i|
    %i[response request].each do |env|
      next unless i.send(env).headers.keys.include?('Token')

      i.send(env).headers.update('Token' => '<SESSION_TOKEN>')
    end
  end
end
