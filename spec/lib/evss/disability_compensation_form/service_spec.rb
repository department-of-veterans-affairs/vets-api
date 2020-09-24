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
          expect { @response = subject.get_rated_disabilities }.to trigger_statsd_increment(
            'api.external_http_request.EVSS/DisabilityCompensationForm.success',
            times: 1,
            value: 1
          )
          expect(@response).to be_ok
          expect(@response).to be_an EVSS::DisabilityCompensationForm::RatedDisabilitiesResponse
          expect(@response.rated_disabilities.count).to eq 2
          expect(@response.rated_disabilities.first.special_issues).to be_an Array
          expect(@response.rated_disabilities.first.special_issues.first)
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
          'api.evss.get_rated_disabilities.fail', tags: ['error:CommonExceptionsGatewayTimeout']
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

    context 'with valid BDD input' do
      let(:valid_bdd_form_content) do
        File.read 'spec/support/disability_compensation_form/bdd_fe_submission.json'
      end

      it 'returns a form submit response object' do
        # TODO: this cassette seems hand-written and is missing a body
        VCR.use_cassette('evss/disability_compensation_form/submit_form_v2') do
          response = subject.submit_form526(valid_bdd_form_content)
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
          'api.evss.submit_form526.fail', tags: ['error:CommonExceptionsGatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.evss.submit_form526.total')
        expect { subject.submit_form526(valid_form_content) }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end

    context 'with a breakers error' do
      it 'logs an error and raise GatewayTimeout' do
        EVSS::DisabilityCompensationForm::Configuration.instance.breakers_service.begin_forced_outage!
        expect { subject.submit_form526(valid_form_content) }
          .to raise_error(Breakers::OutageException)
          .and trigger_statsd_increment(
            'api.external_http_request.EVSS/DisabilityCompensationForm.skipped',
            times: 1,
            value: 1
          ).and trigger_statsd_increment('api.evss.submit_form526.fail',
                                         times: 1,
                                         value: 1,
                                         tags: ['error:BreakersOutageException'])
        EVSS::DisabilityCompensationForm::Configuration.instance.breakers_service.end_forced_outage!
      end
    end
  end
end
