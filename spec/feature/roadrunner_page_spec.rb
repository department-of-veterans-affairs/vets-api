require "rails_helper"

RSpec.feature "Roadrunner Page" do
  it "beep beeps" do
    visit "/"
    expect(find("#beeps").text).to_not have_content("beep beep")

    click_on "Poke the roadrunner"
    expect(find("#beeps")).to have_content("beep beep")

    click_on "Poke the roadrunner"
    expect(find("#beeps")).to have_content("beep beep, beep beep")
  end
end
