# frozen_string_literal: true

RSpec.shared_context 'callback_setup' do
  subject { get(:callback, params: {}.merge(code).merge(state).merge(error_params)) }

  let(:code) { { code: code_value } }
  let(:state) { { state: state_value } }
  let(:error_params) { {} }
  let(:state_value) { 'some-state' }
  let(:code_value) { 'some-code' }
  let(:statsd_tags) { ["type:#{type}", "client_id:#{client_id}", "ial:#{ial}", "acr:#{acr}", "operation:#{operation}"] }
  let(:type) {}
  let(:acr) { nil }
  let(:ial) { nil }
  let(:mpi_update_profile_response) { create(:add_person_response) }
  let(:mpi_add_person_response) { create(:add_person_response, parsed_codes: { icn: add_person_icn }) }
  let(:add_person_icn) { nil }
  let(:find_profile) { create(:find_profile_response, profile: mpi_profile) }
  let(:mpi_profile) { nil }
  let(:client_id) { client_config.client_id }
  let(:authentication) { SignIn::Constants::Auth::API }
  let!(:client_config) do
    create(:client_config,
           authentication:,
           enforced_terms:,
           terms_of_use_url:,
           credential_service_providers: %w[idme logingov mhv],
           service_levels: %w[loa1 loa3 ial1 ial2 min])
  end
  let(:enforced_terms) { nil }
  let(:terms_of_use_url) { 'some-terms-of-use-url' }
  let(:operation) { SignIn::Constants::Auth::VERIFY_CTA_AUTHENTICATED }

  before do
    allow(Rails.logger).to receive(:info)
    allow_any_instance_of(MPI::Service).to receive(:update_profile).and_return(mpi_update_profile_response)
    allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(find_profile)
    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(find_profile)
    allow_any_instance_of(MPI::Service).to receive(:add_person_implicit_search).and_return(mpi_add_person_response)
  end
end
