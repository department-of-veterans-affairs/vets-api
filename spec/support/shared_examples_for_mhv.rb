shared_examples 'for user account level' do |options|
  it "with MHV account level #{options[:account_level]}" do
    expect(response).not_to be_success
    expect(response.status).to eq(403)
    expect(JSON.parse(response.body)['errors'].first['detail']).to eq(options[:message])
  end
end

shared_examples 'for user that is not a va patient' do |options|
  let(:va_patient) { false }

  it "is #{options[:authorized] ? '' : 'NOT'} authorized" do
    expect(response).not_to be_success
    expect(response.status).to eq(403)
    expect(JSON.parse(response.body)['errors'].first['detail']).to eq(options[:message])
  end
end
