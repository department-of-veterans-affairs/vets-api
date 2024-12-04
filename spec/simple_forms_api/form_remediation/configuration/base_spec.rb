# frozen_string_literal: true

require 'spec_helper'
require_relative '../simple_forms_api/form_remediation/configuration/base'

RSpec.describe SimpleFormsApi::FormRemediation::Configuration::Base do
  describe '#initialize'
  describe '#submission_archive_class'
  describe '#s3_client'
  describe '#remediation_data_class'
  describe '#uploader_class'
  describe '#submission_type'
  describe '#attachment_type'
  describe '#temp_directory_path'
  describe '#s3_settings'
  describe '#log_info'
  describe '#log_error'
  describe '#handle_error'
end
