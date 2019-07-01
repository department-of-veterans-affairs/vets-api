require 'rails_helper'
require 'generators/module/module_generator'

describe ModuleGenerator do
  it "creates a test initializer" do
    ModuleGenerator.new(['foo']).create_app
    expect(File).to exist("#{Rails.root}/modules/foo/app/controllers/foo/v0/foo_controller.rb")
  end
end
