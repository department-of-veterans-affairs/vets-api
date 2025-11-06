# frozen_string_literal: true

RSpec.shared_context 'logingov_logout_proxy_setup' do
  subject { get(:logingov_logout_proxy, params: logingov_logout_proxy_params) }

  let(:logingov_logout_proxy_params) do
    {}.merge(state)
  end
  let(:state) { { state: state_value } }
  let(:state_value) { 'some-state-value' }

  before { allow(Rails.logger).to receive(:info) }
end
