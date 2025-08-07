# frozen_string_literal: true

require 'rails_helper'

class BypassOliveBranchTestController < ActionController::API
  def arp = render json: {}
  def normal = render json: {}
end

RSpec.describe AccreditedRepresentativePortal::BypassOliveBranch, type: :request do
  subject do
    get "#{path_prefix}/bypass_olive_branch_test", headers: {
      'X-Key-Inflection' => 'camel',
      'Content-Type' => 'application/json'
    }
  end

  before(:all) do
    Rails.application.routes.draw do
      get '/accredited_representative_portal/bypass_olive_branch_test', to: 'bypass_olive_branch_test#arp'
      get '/bypass_olive_branch_test', to: 'bypass_olive_branch_test#normal'
    end
  end

  after(:all) do
    Rails.application.reload_routes!
  end

  context 'when the request is for an accredited representative portal route' do
    let(:path_prefix) { '/accredited_representative_portal' }

    it 'bypasses OliveBranch processing' do
      expect(OliveBranch::Transformations).not_to receive(:underscore_params)
      expect(OliveBranch::Transformations).not_to receive(:transform)
      subject
    end
  end

  ##
  # Our reverse proxy for deployed environments prepends an extra slash at the
  # beginning. Offending nginx conf here:
  # https://github.com/department-of-veterans-affairs/devops/blob/c84a83696357b84e155c8ec849934af3019da769/ansible/deployment/config/revproxy-vagov/templates/nginx_api_server.conf.j2#L121
  #
  context 'when the request is for an accredited representative portal route with an extra slash prepended' do
    let(:path_prefix) { '//accredited_representative_portal' }

    it 'bypasses OliveBranch processing' do
      expect(OliveBranch::Transformations).not_to receive(:underscore_params)
      expect(OliveBranch::Transformations).not_to receive(:transform)
      subject
    end
  end

  context 'when the request is for a normal route' do
    let(:path_prefix) { '' }

    it 'applies OliveBranch processing' do
      expect(OliveBranch::Transformations).to receive(:underscore_params)
      expect(OliveBranch::Transformations).to receive(:transform)
      subject
    end
  end
end
