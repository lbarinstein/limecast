require File.dirname(__FILE__) + '/../spec_ui_helper'

describe "Adding podcast while logged out" do
  before(:each) do
    browser.go("/add")
    browser.text_field(:name, "feed[url]").set("#{browser.url}/test_data/wine-library-tv.rss")
    browser.button(:value, "Add").click
  end

  it 'should immediately show the loading status' do
    html.should have_tag("div.status_message", /Getting RSS/)
  end

  it 'should eventually show success' do
    try_for(60) do
      html.should have_tag("div.status_message", /Yum/)
    end
  end
end

describe "Adding podcast while logged in" do
  before(:each) do
    sign_in
    browser.go("/add")
    browser.text_field(:name, "feed[url]").set("#{browser.url}/test_data/wine-library-tv.rss")
    browser.button(:value, "Add").click
  end

  it 'should not show the inline signin' do
  end
end
