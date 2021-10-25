# frozen_string_literal: true

require 'rails_helper'
require 'okta/directory_service'
require 'okta/service'
require 'vcr'

RSpec.describe Okta::DirectoryService do
  let(:subject) { described_class.new }
  let(:server_scopes) do
    {
      'body' => [
        {
          id: 'dsfdsafdsfdsl',
          name: 'launch/patient',
          displayName: 'Patient ID',
          description: 'Your unique VA ID number....',
          system: false,
          metadataPublish: 'ALL_CLIENTS',
          consent: 'REQUIRED',
          default: false,
          _links: {
            self: {
              href: 'fakewebsite',
              hints: {
                allow: %w[
                  GET
                  PUT
                  DELETE
                ]
              }
            }
          }
        },
        {
          id: 'fdsafdsaff',
          name: 'patient/AllergyIntolerance.read',
          displayName: 'Allergies',
          description: 'A list of any substances.....',
          system: false,
          metadataPublish: 'ALL_CLIENTS',
          consent: 'REQUIRED',
          default: false,
          _links: {
            self: {
              href: 'fakewebsite',
              hints: {
                allow: %w[
                  GET
                  PUT
                  DELETE
                ]
              }
            }
          }
        },
        {
          id: 'fdsafdsaff',
          name: 'email',
          displayName: 'email',
          description: 'email',
          system: false,
          metadataPublish: 'ALL_CLIENTS',
          consent: 'REQUIRED',
          default: false,
          _links: {
            self: {
              href: 'fakewebsite',
              hints: {
                allow: %w[
                  GET
                  PUT
                  DELETE
                ]
              }
            }
          }
        }
      ]
    }
  end
  let(:server_hash_struct) { OpenStruct.new(server_scopes) }

  describe '#initialize' do
    it 'creates the okta service correctly' do
      expect(subject.okta_service).to be_instance_of(Okta::Service)
    end
  end

  describe '#scopes' do
    it 'directs to #handle_health_server as expected' do
      allow_any_instance_of(Okta::DirectoryService).to receive(:scopes).with('health').and_return('boop')
      expect(subject.scopes('health')).to be('boop')
    end
    it 'directs to #handle_nonhealth_server as expected' do
      allow_any_instance_of(Okta::DirectoryService).to receive(:scopes).with('verification').and_return('beep')
      expect(subject.scopes('verification')).to be('beep')
    end
  end

  describe '#handle_health_server' do
    before do
      allow(Settings.directory).to receive(:health_server_id).and_return('ausa6g29u50OhqAdv2p7')
    end

    it 'returns a body' do
      VCR.use_cassette('okta/health_scopes', match_requests_on: %i[method path]) do
        response = subject.handle_health_server
        expect(response).not_to be_nil
      end
    end
  end

  describe '#handle_nonhealth_server' do
    it 'handles nonhealth servers as expected' do
      VCR.use_cassette('okta/verification_scopes', match_requests_on: %i[method path]) do
        response = subject.handle_nonhealth_server('verification')
        expect(response).not_to be_nil
      end
    end
    it 'returns an empty server when passed an invalid category' do
      VCR.use_cassette('okta/invalid_scopes', match_requests_on: %i[method path]) do
        response = subject.handle_nonhealth_server('somethingthatdoesntexist')
        expect(response).to eq([])
      end
    end
  end

  describe '#remove_scope_keys' do
    it 'removes unnecessary keys as expected' do
      response = subject.remove_scope_keys(server_hash_struct)
      expect(response.first[:name]).not_to be_nil
      expect(response.first[:displayName]).not_to be_nil
      expect(response.first[:description]).not_to be_nil
      # these three were part of the original hash and should be removed
      expect(response.first[:uuid]).to be_nil
      expect(response.first[:system]).to be_nil
      expect(response.first[:consent]).to be_nil
      expect(response.first[:metadataPublish]).to be_nil
    end
  end
end
