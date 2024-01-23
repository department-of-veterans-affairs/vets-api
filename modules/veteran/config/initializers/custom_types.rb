# frozen_string_literal: true

require 'veteran/flag_type'

ActiveRecord::Type.register(:flag_type, Veteran::FlagType)
