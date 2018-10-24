# frozen_string_literal: true

# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Rails.application.initialize!

ActiveRecord::SchemaDumper.ignore_tables = ['spatial_ref_sys']
