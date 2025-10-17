# frozen_string_literal: true

require 'rails_helper'
require 'vye/dgib/response'

RSpec.describe Vye::DGIB::Response do
  # Helper method to transform fixture data from camelCase to snake_case
  # This mimics the transformation that happens in production via Faraday's :snakecase middleware
  # which converts API responses from external services (camelCase) to Ruby convention (snake_case)
  # Our fixtures are in camelCase which is how they come from the external service
  def transformed_fixture_body(fixture_path)
    JSON.parse(File.read(fixture_path)).deep_transform_keys(&:underscore)
  end

  describe 'Response base class' do
    describe '#ok?' do
      it 'returns true when status is 200' do
        response = described_class.new(200)
        expect(response.ok?).to be(true)
      end

      it 'returns false when status is not 200' do
        response = described_class.new(404)
        expect(response.ok?).to be(false)
      end
    end

    describe '#cache?' do
      it 'returns true when status is 200' do
        response = described_class.new(200)
        expect(response.cache?).to be(true)
      end

      it 'returns false when status is not 200' do
        response = described_class.new(500)
        expect(response.cache?).to be(false)
      end
    end

    describe '#metadata' do
      it 'returns metadata with response status' do
        response = described_class.new(200)
        expect(response.metadata).to eq({ status: response.response_status })
      end
    end

    describe '#response_status' do
      it 'returns :ok for status 200' do
        response = described_class.new(200)
        expect(response.response_status).to eq(Vye::DGIB::Response::RESPONSE_STATUS[:ok])
      end

      it 'returns :no_content for status 204' do
        response = described_class.new(204)
        expect(response.response_status).to eq(Vye::DGIB::Response::RESPONSE_STATUS[:no_content])
      end

      it 'returns :not_authorized for status 403' do
        response = described_class.new(403)
        expect(response.response_status).to eq(Vye::DGIB::Response::RESPONSE_STATUS[:not_authorized])
      end

      it 'returns :not_found for status 404' do
        response = described_class.new(404)
        expect(response.response_status).to eq(Vye::DGIB::Response::RESPONSE_STATUS[:not_found])
      end

      it 'returns :internal_server_error for status 500' do
        response = described_class.new(500)
        expect(response.response_status).to eq(Vye::DGIB::Response::RESPONSE_STATUS[:internal_server_error])
      end

      it 'returns :server_error for other status codes' do
        response = described_class.new(502)
        expect(response.response_status).to eq(Vye::DGIB::Response::RESPONSE_STATUS[:server_error])
      end
    end
  end

  describe Vye::DGIB::ClaimantStatusResponse do
    let(:mock_response_body) { transformed_fixture_body('modules/vye/spec/fixtures/claimant_response.json') }
    let(:mock_response) { double('response', body: mock_response_body) }

    describe '#initialize' do
      it 'sets attributes from response body' do
        response = described_class.new(200, mock_response)

        expect(response.status).to eq(200)
        expect(response.claimant_id).to eq(600_010_259)
        expect(response.delimiting_date).to eq('2022-02-09')
        expect(response.payment_on_hold).to be(false)
      end

      it 'raises an error for nil response' do
        expect { described_class.new(404, nil) }.to raise_error(NoMethodError)
      end
    end
  end

  describe Vye::DGIB::ClaimantLookupResponse do
    let(:mock_response_body) { transformed_fixture_body('modules/vye/spec/fixtures/claimant_lookup_response.json') }
    let(:mock_response) { double('response', body: mock_response_body) }

    describe '#initialize' do
      it 'sets claimant_id from response body' do
        response = described_class.new(200, mock_response)

        expect(response.status).to eq(200)
        expect(response.claimant_id).to eq(600_010_259)
      end

      it 'raises an error for nil response' do
        expect { described_class.new(404, nil) }.to raise_error(NoMethodError)
      end
    end
  end

  describe Vye::DGIB::VerificationRecordResponse do
    let(:mock_response_body) do
      transformed_fixture_body('modules/vye/spec/fixtures/mock_verification_record_response.json')
    end
    let(:mock_response) { double('response', body: mock_response_body) }

    describe '#initialize' do
      it 'sets attributes from response body' do
        response = described_class.new(200, mock_response)

        expect(response.status).to eq(200)
        expect(response.claimant_id).to eq(0)
        expect(response.delimiting_date).to eq('2024-11-01')
        expect(response.enrollment_verifications).to eq(
          [
            {
              'verification_month' => 'December 2023',
              'verification_begin_date' => '2024-11-01',
              'verification_end_date' => '2024-11-01',
              'verification_through_date' => '2024-11-01',
              'created_date' => '2024-11-01',
              'verification_method' => '',
              'verification_response' => 'Y',
              'facility_name' => 'string',
              'total_credit_hours' => 0,
              'payment_transmission_date' => '2024-11-01',
              'last_deposit_amount' => 0,
              'remaining_entitlement' => '53-01'
            }
          ]
        )

        expect(response.verified_details).to eq(
          [
            {
              'benefit_type' => 'CH33',
              'verified_through_date' => '2024-11-01',
              'verification_method' => 'Initial'
            }
          ]
        )
        expect(response.payment_on_hold).to be(true)
      end

      it 'raises an error for nil response' do
        expect { described_class.new(404, nil) }.to raise_error(NoMethodError)
      end
    end
  end

  describe Vye::DGIB::VerifyClaimantResponse do
    let(:mock_response_body) { transformed_fixture_body('modules/vye/spec/fixtures/verify_claimant_response.json') }
    let(:mock_response) { double('response', body: mock_response_body) }

    describe '#initialize' do
      it 'sets attributes from response body' do
        response = described_class.new(200, mock_response)

        expect(response.status).to eq(200)
        expect(response.claimant_id).to eq(600_010_259)
        expect(response.delimiting_date).to eq('2022-02-09')
        expect(response.verified_details).to eq(["['verifiedd1', 'verifiedd2', 'verifiedd3']"])
        expect(response.payment_on_hold).to be(false)
      end

      it 'raises an error for nil response' do
        expect { described_class.new(404, nil) }.to raise_error(NoMethodError)
      end
    end
  end
end
