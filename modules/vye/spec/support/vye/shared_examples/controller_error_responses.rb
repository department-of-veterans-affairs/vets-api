# frozen_string_literal: true

RSpec.shared_examples 'handles error response' do |factory_trait, expected_status, status_name|
  let(:verification_record_response) { build(:verification_record_response, factory_trait) }

  it "returns #{expected_status} status and empty response body" do
    post :verification_record, params: { claimant_id: }
    expect(response).to have_http_status(status_name)
    expect(response.body).to eq ''
  end

  it 'handles nil values correctly in the serializer' do
    serializer = Vye::ClaimantVerificationSerializer.new(verification_record_response)
    json_output = JSON.parse(serializer.to_json)
    expect(json_output.values).to all(satisfy { |v| v.nil? || v == [] })
  end
end

RSpec.shared_examples 'logs error response' do |log_message_pattern|
  before do
    allow(Rails.logger).to receive(:error)
  end

  it 'logs the error' do
    expect(Rails.logger).to receive(:error).with(log_message_pattern)
    post :verification_record, params: { claimant_id: }
  end
end
