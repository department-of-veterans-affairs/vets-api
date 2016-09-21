# frozen_string_literal: true
require 'rails_helper'

describe SM::Client do
  let(:session_options) { attributes_for :session, :valid_user }
  let(:config_options) { attributes_for :configuration }

  subject { described_class.new(options) }

  context 'without attributes' do
    let(:options) { {} }
    it { expect { subject }.to raise_error(ArgumentError, 'missing keywords: config, session') }
  end

  describe 'when initialized' do
    context 'with a hash' do
      let(:options) { { session: session_options, config: config_options } }

      it 'should have a complete configuration' do
        app_token = config_options[:app_token]
        base_path = "#{config_options[:host]}/mhv-sm-api/patient/v1/"

        expect(subject.config).to have_attributes(app_token: app_token,
                                                  open_timeout: 15,
                                                  read_timeout: 15,
                                                  base_path: base_path)
      end

      it 'should have a session object' do
        session_attributes = SM::ClientSession.new(session_options).attributes
        expect(subject.session.attributes).to eq(session_attributes)
      end
    end

    context 'when initialized with objects' do
      let(:session) { SM::ClientSession.new(session_options) }
      let(:config) { SM::Configuration.new(config_options) }
      let(:options) { { session: session, config: config } }

      it 'should have a complete config' do
        app_token = config_options[:app_token]
        base_path = "#{config_options[:host]}/mhv-sm-api/patient/v1/"

        expect(subject.config).to have_attributes(app_token: app_token, open_timeout: 15, read_timeout: 15,
                                                  base_path: base_path)
      end

      it 'should have a session object' do
        session_attributes = SM::ClientSession.new(session_options).attributes
        expect(subject.session.attributes).to eq(session_attributes)
      end
    end
  end
end
