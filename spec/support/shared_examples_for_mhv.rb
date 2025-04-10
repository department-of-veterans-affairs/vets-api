# frozen_string_literal: true

shared_examples 'for user account level' do |options|
  it "with MHV account level #{options[:account_level]}" do
    expect(response).not_to be_successful
    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)['errors'].first['detail']).to eq(options[:message])
  end
end

shared_examples 'for non va patient user' do |options|
  let(:va_patient) { false }

  it "is #{options[:authorized] ? '' : 'NOT'} authorized" do
    expect(response).not_to be_successful
    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)['errors'].first['detail']).to eq(options[:message])
  end
end 