# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/veteran_status/service'

describe VAProfile::VeteranStatus::Service do
  let(:user) { build(:user, :loa3) }
  let(:edipi) { '1005127153' }
  subject { described_class.new(user) }

  before do
    allow(user).to receive(:edipi).and_return(edipi)
  end

  describe '#identity_path' do
    context 'when an edipi exists' do
      it 'returns a valid identity path' do
        path = subject.identity_path
        expect(path).to eq('2.16.840.1.113883.3.42.10001.100001.12/1005127153%5ENI%5E200DOD%5EUSDOD')
      end
    end
  end

  describe 'get_veteran_status' do
    context 'with a valid request' do
      it 'calls the get_veteran_status endpoint with a proper emis message' do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200') do
          response = subject.get_veteran_status
          expect(response).to be_ok
        end
      end

      it 'gives me the right values back' do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200') do
          response = subject.get_veteran_status
         # binding.pry
          expect(response.title38_status_code.title38_status_code).to eq('V1')
        end
      end
    end

    context 'throws an error' do
      it 'gives me a 400 response' do
        VCR.use_cassette('va_profile/veteran_status/veteran_status_400_') do
          response = subject.get_veteran_status
          expect(response).not_to be_ok
          expect(response.status).to eq(400)
          expect(response.veteran_status_title).to eq(nil)
          expect(response.title38_status).to eq(nil)

                    #TODO test log_exception_to_sentry
        end
      end
    end

  #   context 'with a missing edipi' do
  #     it 'gives me a missing response' do
  #       VCR.use_cassette('emis/get_veteran_status/missing_edipi') do
  #         response = subject.get_veteran_status(edipi: missing_edipi)
  #         expect(response).not_to be_ok
  #         expect(response).to be_empty
  #         expect(response.error?).to eq(false)
  #         expect(response.error).to eq(nil)
  #       end
  #     end
  #   end

  #   context 'with an empty response element' do
  #     it 'returns nil' do
  #       VCR.use_cassette('emis/get_veteran_status/empty_title38') do
  #         response = subject.get_veteran_status(edipi: no_status)
  #         expect(response.items.first).to be_nil
  #       end
  #     end
    end
  # end
end

# module EMIS
#   class BrokenVeteranStatusService < Service
#     configuration EMIS::VeteranStatusConfiguration

#     create_endpoints([[:get_veteran_status, 'fooRequest']])

#     def custom_namespaces
#       {}
#     end
#   end
# end

# describe EMIS::BrokenVeteranStatusService do
#   let(:edipi) { '1607472595' }

#   it 'gives me back an error' do
#     VCR.use_cassette('emis/get_veteran_status/broken') do
#       response = subject.get_veteran_status(edipi:)
#       expect(response).to be_an_instance_of(EMIS::Responses::ErrorResponse)
#       expect(response.error).to be_an_instance_of(Common::Client::Errors::HTTPError)
#       expect(response.error.message).to be('SOAP HTTP call failed')
#     end
#   end
# end

