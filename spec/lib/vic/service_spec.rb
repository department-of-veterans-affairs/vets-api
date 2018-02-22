# frozen_string_literal: true

require 'rails_helper'

describe VIC::Service do
  let(:parsed_form) { JSON.parse(create(:vic_submission).form) }
  let(:service) { described_class.new }
  let(:user) { build(:evss_user) }
  let(:client) { double }
  let(:case_id) { 'case_id' }

  describe '#get_oauth_token' do
    it 'should get the access token from the request', run_at: '2018-02-06 21:51:48 -0500' do
      oauth_params = get_fixture('vic/oauth_params').symbolize_keys
      return_val = OpenStruct.new(body: { 'access_token' => 'token' })
      expect(service).to receive(:request).with(:post, '', oauth_params).and_return(return_val)

      expect(service.get_oauth_token).to eq('token')
    end
  end

  describe '#add_user_data!' do
    it 'should add user data to the request form' do
      converted_form = { 'profile_data' => {} }
      expect(user.veteran_status).to receive(:title38_status).and_return('V1')
      service.add_user_data!(converted_form, user)
      expect(converted_form).to eq(
        'profile_data' => {
          'sec_ID' => '0001234567', 'active_ICN' => user.icn
        },
        'title38_status' => 'V1'
      )
    end
  end

  describe '#convert_form' do
    it 'should format the form' do
      expect(service.convert_form(parsed_form)).to eq(
        'service_branch' => 'Air Force',
        'email' => 'foo@foo.com',
        'veteran_full_name' => { 'first' => 'Mark', 'last' => 'Olson' },
        'veteran_address' => {
          'city' => 'Milwaukee',
          'country' => 'US', 'postal_code' => '53130',
          'state' => 'WI', 'street' => '123 Main St', 'street2' => ''
        },
        'phone' => '5551110000',
        'profile_data' => { 'SSN' => '111223333', 'historical_ICN' => [] }
      )
    end
  end

  describe '#all_files_processed?' do
    it 'should see if the files are processed yet' do
      expect(service.all_files_processed?(parsed_form)).to eq(false)
      ProcessFileJob.drain
      expect(service.all_files_processed?(parsed_form)).to eq(true)
    end
  end

  describe '#send_files' do
    it 'should send the files in the form' do
      parsed_form
      ProcessFileJob.drain
      expect(service).to receive(:send_file).with(
        client, case_id,
        VIC::SupportingDocumentationAttachment.last.get_file.read,
        'Supporting Documentation'
      )
      expect(service).to receive(:send_file).with(
        client, case_id,
        VIC::ProfilePhotoAttachment.last.get_file.read,
        'Profile Photo'
      )
      service.send_files(client, case_id, parsed_form)
    end
  end

  describe '#send_file' do
    it 'should read the mime type and send the file' do
      upload_io = double
      expect(SecureRandom).to receive(:hex).and_return('hex')
      expect(Restforce::UploadIO).to receive(:new).with(
        'tmp/hex.pdf', 'application/pdf'
      ).and_return(upload_io)

      expect(client).to receive(:create).with(
        'Attachment',
        ParentId: case_id,
        Description: 'description',
        Name: 'hex.pdf',
        Body: upload_io
      )

      service.send_file(client, case_id, File.read('spec/fixtures/pdf_fill/extras.pdf'), 'description')
    end
  end

  describe '#submit' do
    before do
      expect(service).to receive(:convert_form).with(parsed_form).and_return({})
      expect(service).to receive(:get_oauth_token).and_return('token')

      expect(Restforce).to receive(:new).with(
        oauth_token: 'token',
        instance_url: VIC::Configuration::SALESFORCE_INSTANCE_URL,
        api_version: '41.0'
      ).and_return(client)
      expect(client).to receive(:post).with(
        '/services/apexrest/VICRequest', {}
      ).and_return(
        OpenStruct.new(
          body: {
            'case_id' => 'case_id',
            'case_number' => 'case_number'
          }
        )
      )

      expect(service).to receive(:send_files).with(client, 'case_id', parsed_form)
    end

    def test_case_id(user)
      parsed_form
      ProcessFileJob.drain
      expect(service.submit(parsed_form, user)).to eq(case_id: 'case_id', case_number: 'case_number')
    end

    context 'with a user' do
      it 'should submit the form and attached documents' do
        expect(service).to receive(:add_user_data!).with({}, user)
        test_case_id(user)
      end
    end

    context 'with no user' do
      it 'should submit the form' do
        test_case_id(nil)
      end
    end
  end
end
