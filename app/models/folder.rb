# frozen_string_literal: true
require 'common/models/base'

# Folder model
class Folder < Common::Base
  attribute :folder_id, Integer
  attribute :name, String
  attribute :count, Integer
  attribute :unread_count, Integer
  attribute :system_folder, Boolean

  alias system_folder? system_folder

  def <=>(other)
    name <=> other.name
  end
end
