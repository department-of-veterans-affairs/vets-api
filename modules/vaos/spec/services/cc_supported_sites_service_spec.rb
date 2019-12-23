# frozen_string_literal: true

require 'rails_helper'

describe VAOS::CCSupportedSitesService do
  subject { VAOS::CCSupportedSitesService.new(user) }

  let(:user) { build(:user, :vaos) }
  let(:site_codes) { '983,984' }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_supported_sites', :skip_mvi do
    it 'gets a single supported site' do
      VCR.use_cassette('vaos/cc_supported_sites/get_one_site', match_requests_on: %i[method uri]) do
        response = subject.get_supported_sites(site_codes)
        expect(response[:data].id).to eq('983')
      end
    end

    it 'gets no supported sites' do
      let(:site_codes) { '1,2,3' }
      VCR.use_cassette('vaos/cc_supported_sites/get_no_sites', match_requests_on: %i[method uri]) do
        response = subject.get_supported_sites(site_codes)
        expect(response[:data].id).to be_nil
      end
    end

    context 'invalid site_codes' do
      let(:site_codes) { '' }

      it 'handles bad parameters appropriately' do
        VCR.use_cassette('vaos/cc_supported_sites/get_supported_sites_error', match_requests_on: %i[method uri]) do
          expect { subject.get_supported_sites(site_codes) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
