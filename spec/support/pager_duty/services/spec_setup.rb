# frozen_string_literal: true

RSpec.shared_context 'simulating Redis caching of PagerDuty#get_services' do
  let(:get_services_response) do
    VCR.use_cassette('pager_duty/external_services/get_services', VCR::MATCH_EVERYTHING) do
      PagerDuty::ExternalServices::Service.new.get_services
    end
  end

  before do
    allow_any_instance_of(
      PagerDuty::ExternalServices::Service
    ).to receive(:get_services).and_return(get_services_response)

    allow_any_instance_of(ExternalServicesRedis::Status).to receive(:cache).and_return(true)
  end
end
