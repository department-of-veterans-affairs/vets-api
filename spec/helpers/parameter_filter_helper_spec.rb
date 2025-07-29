# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/helpers/parameter_filter_helper'

RSpec.describe ParameterFilterHelper do
  describe '.filter_params' do
    it 'filters sensitive values from a hash' do
      params = { password: 'secret', 'ssn' => '123-45-6789' }
      filtered = described_class.filter_params(params)
      expect(filtered[:password]).to eq('[FILTERED]')
      expect(filtered['ssn']).to eq('[FILTERED]')
    end

    it 'does not filter allowlisted keys' do
      params = { 'controller' => 'posts', 'action' => 'show' }
      filtered = described_class.filter_params(params)
      expect(filtered['controller']).to eq('posts')
      expect(filtered['action']).to eq('show')
    end

    it 'filters complex nested hash and arrays' do
      params = { id: 12_345, ssn: '123456789', class: String, not_whitelisted: [{ id: 1 }],
                 errors: [{ class: 'TEST', should_omit: 'FOOBAR' }] }
      expected = { id: 12_345,
                   ssn: '[FILTERED]',
                   class: String,
                   not_whitelisted: '[FILTERED]',
                   errors: [{ class: 'TEST', should_omit: '[FILTERED]' }] }
      filtered = described_class.filter_params(params)
      expect(filtered).to eq expected
    end

    it 'filters sensitive values from ActionDispatch::Http::UploadedFile in params' do
      file = ActionDispatch::Http::UploadedFile.new(
        tempfile: Tempfile.new('test'),
        filename: 'secret.txt',
        type: 'text/plain',
        head: 'headers'
      )

      filtered_params = { attachment: described_class.filter_params(file) }

      # Check that the filtered param is still an ActionDispatch::Http::UploadedFile
      expect(filtered_params[:attachment]).to be_a(ActionDispatch::Http::UploadedFile)

      # Check that the sensitive instance variables are filtered
      expect(filtered_params[:attachment].instance_variable_get(:@original_filename)).to eq('[FILTERED!]')
      expect(filtered_params[:attachment].instance_variable_get(:@headers)).to eq('[FILTERED!]')

      # Optionally, check allowlisted fields are not filtered
      expect(filtered_params[:attachment].instance_variable_get(:@tempfile)).not_to eq('[FILTERED!]')
      expect(filtered_params[:attachment].instance_variable_get(:@content_type)).not_to eq('[FILTERED!]')
    end

    it 'filters values that might contain sensitive info, if key is not allowlisted' do
      params = { message_content: 'password=secret' }
      filtered = described_class.filter_params(params)
      expect(filtered[:message_content]).to eq('[FILTERED]')
    end

    it 'does not filter values for allowlisted keys' do
      loggable_params = { controller: 'mycontroller' }
      filtered = Rails.application.config.filter_parameters.first.call(nil, loggable_params.deep_dup)
      Rails.logger.info('Parameters for document upload', filtered)
      expect(filtered[:controller]).to eq('mycontroller')
    end
  end
end
