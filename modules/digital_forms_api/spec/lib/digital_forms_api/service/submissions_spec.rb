# frozen_string_literal: true

require 'rails_helper'

require 'digital_forms_api/service/submissions'

require_relative 'shared/service'

RSpec.describe DigitalFormsApi::Service::Submissions do
  let(:service) { described_class.new }

  let(:payload) do
    { data: 'TEST' }
  end
  let(:metadata) do
    {
      formId: '99t-12345',
      veteranId: '123456789v12345',
      claimantId: 'another-identifier',
      epCode: '99999999',
      claimLabel: '99999999DPEBNAJRE'
    }
  end

  let(:uuid) { SecureRandom.hex }

  it_behaves_like 'a DigitalFormsApi::Service class'

  describe 'submit' do
    it 'performs a POST' do
      expected = metadata.deep_dup
      expected[:claimantId] = { identifierType: 'PARTICIPANTID', value: expected[:claimantId] }
      expected[:veteranId] = { identifierType: 'PARTICIPANTID', value: expected[:veteranId] }

      expected = { envelope: expected.merge({ payload: }) }

      expect(service).to receive(:perform).with(:post, 'submissions?dry-run=false', expected, {})
      service.submit(payload, metadata)
    end
  end

  describe 'retrieve' do
    it 'performs a GET' do
      expect(service).to receive(:perform).with(:get, "submissions/#{uuid}", {}, {})
      service.retrieve(uuid)
    end
  end

  describe 'submit_and_resolve_uuid' do
    let(:submit_response) do
      OpenStruct.new(
        body: {
          'submission' => {
            'submissionId' => 'a1ba50e4-e689-4852-bec7-2a66519f0ed3',
            'claimId' => '123456789',
            'claimantId' => '600123456'
          }
        }
      )
    end

    let(:retrieve_response) do
      OpenStruct.new(
        body: {
          'submission' => {
            'submissionId' => 'a1ba50e4-e689-4852-bec7-2a66519f0ed3',
            'claimId' => '123456789',
            'participantId' => '600123456',
            'userUuid' => '8f09dc36-8d09-4de0-a02e-c8f8f0f9d7c8'
          }
        }
      )
    end

    it 'submits, retrieves, and resolves uuid details' do
      expect(service).to receive(:submit).with(payload, metadata, dry_run: false).and_return(submit_response)
      expect(service).to receive(:retrieve).with('a1ba50e4-e689-4852-bec7-2a66519f0ed3').and_return(retrieve_response)

      result = service.submit_and_resolve_uuid(payload, metadata)

      expect(result[:submission_id]).to eq('a1ba50e4-e689-4852-bec7-2a66519f0ed3')
      expect(result[:claim_id]).to eq('123456789')
      expect(result[:participant_id]).to eq('600123456')
      expect(result[:resolved_user_uuid]).to eq('8f09dc36-8d09-4de0-a02e-c8f8f0f9d7c8')
      expect(result[:submit_response]).to eq(submit_response)
      expect(result[:retrieve_response]).to eq(retrieve_response)
    end

    it 'returns nil uuid and skips retrieve when submission id is missing' do
      empty_submit_response = OpenStruct.new(body: { 'submission' => {} })
      expect(service).to receive(:submit).with(payload, metadata, dry_run: false).and_return(empty_submit_response)
      expect(service).not_to receive(:retrieve)

      result = service.submit_and_resolve_uuid(payload, metadata)

      expect(result[:submission_id]).to be_nil
      expect(result[:claim_id]).to be_nil
      expect(result[:participant_id]).to be_nil
      expect(result[:resolved_user_uuid]).to be_nil
      expect(result[:submit_response]).to eq(empty_submit_response)
      expect(result[:retrieve_response]).to be_nil
    end

    it 'falls back claim_id and participant_id to submit response when retrieve has sparse details' do
      sparse_retrieve_response = OpenStruct.new(body: { 'submission' => { 'submissionId' => 'a1ba50e4-e689-4852-bec7-2a66519f0ed3' } })

      expect(service).to receive(:submit).with(payload, metadata, dry_run: false).and_return(submit_response)
      expect(service).to receive(:retrieve).with('a1ba50e4-e689-4852-bec7-2a66519f0ed3').and_return(sparse_retrieve_response)

      result = service.submit_and_resolve_uuid(payload, metadata)

      expect(result[:claim_id]).to eq('123456789')
      expect(result[:participant_id]).to eq('600123456')
      expect(result[:resolved_user_uuid]).to be_nil
    end

    it 'resolves uuid from alternate key names in retrieved details' do
      alt_uuid_retrieve_response = OpenStruct.new(
        body: {
          'submission' => {
            'submissionId' => 'a1ba50e4-e689-4852-bec7-2a66519f0ed3',
            'resolvedUserUuid' => 'bb8c74b9-4ff0-4ea9-96df-1655de172a1e'
          }
        }
      )

      expect(service).to receive(:submit).with(payload, metadata, dry_run: false).and_return(submit_response)
      expect(service).to receive(:retrieve).with('a1ba50e4-e689-4852-bec7-2a66519f0ed3').and_return(alt_uuid_retrieve_response)

      result = service.submit_and_resolve_uuid(payload, metadata)

      expect(result[:resolved_user_uuid]).to eq('bb8c74b9-4ff0-4ea9-96df-1655de172a1e')
    end

    it 'uses retrieved claimantId when participantId is not present' do
      claimant_only_retrieve_response = OpenStruct.new(
        body: {
          'submission' => {
            'submissionId' => 'a1ba50e4-e689-4852-bec7-2a66519f0ed3',
            'claimantId' => '700999111'
          }
        }
      )

      expect(service).to receive(:submit).with(payload, metadata, dry_run: false).and_return(submit_response)
      expect(service).to receive(:retrieve).with('a1ba50e4-e689-4852-bec7-2a66519f0ed3').and_return(claimant_only_retrieve_response)

      result = service.submit_and_resolve_uuid(payload, metadata)

      expect(result[:participant_id]).to eq('700999111')
    end
  end
end
