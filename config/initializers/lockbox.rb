# frozen_string_literal: true

require 'lockbox'
Lockbox.master_key = Settings.lockbox.master_key
Lockbox.default_options = { padding: true }
