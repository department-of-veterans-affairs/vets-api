# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/service'

describe EVSS::DisabilityCompensationForm::Service do
  subject do
    described_class.new(
      EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    )
  end

  let(:user) { build(:disabilities_compensation_user) }

  describe '#get_rated_disabilities' do
    context 'with a valid evss response' do
      it 'returns a rated disabilities response object' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
          response = subject.get_rated_disabilities
          expect(response).to be_ok
          expect(response).to be_an EVSS::DisabilityCompensationForm::RatedDisabilitiesResponse
          expect(response.rated_disabilities.count).to eq 2
          expect(response.rated_disabilities.first.special_issues).to be_an Array
          expect(response.rated_disabilities.first.special_issues.first)
            .to be_an EVSS::DisabilityCompensationForm::SpecialIssue
        end
      end
    end

    context 'with an http timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
      end

      it 'logs an error and raise GatewayTimeout' do
        expect(StatsD).to receive(:increment).once.with(
          'api.evss.get_rated_disabilities.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.evss.get_rated_disabilities.total')
        expect { subject.get_rated_disabilities }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end
  end

  describe '#submit_form' do
    let(:valid_form_content) do
      File.read 'spec/support/disability_compensation_form/front_end_submission_with_uploads.json'
    end

    context 'with valid input' do
      it 'returns a form submit response object' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form_v2') do
          response = subject.submit_form526(valid_form_content)
          expect(response).to be_ok
          expect(response).to be_an EVSS::DisabilityCompensationForm::FormSubmitResponse
          expect(response.claim_id).to be_an Integer
        end
      end
    end

    context 'with an http timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
      end

      it 'logs an error and raise GatewayTimeout' do
        expect(StatsD).to receive(:increment).once.with(
          'api.evss.submit_form526.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.evss.submit_form526.total')
        expect { subject.submit_form526(valid_form_content) }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end
  end
end
