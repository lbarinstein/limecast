require File.dirname(__FILE__) + '/../../spec_helper'

describe "/podcasts/index.html.erb" do
  include PodcastsHelper
  
  before(:each) do
    podcast_98 = mock_model(Podcast)
    podcast_98.should_receive(:title).and_return("MyString")
    podcast_98.should_receive(:site).and_return("MyString")
    podcast_98.should_receive(:feed).and_return("MyString")
    podcast_98.should_receive(:logo_file_name).and_return("MyString")
    podcast_98.should_receive(:logo_content_type).and_return("MyString")
    podcast_98.should_receive(:logo_file_size).and_return("MyString")
    podcast_99 = mock_model(Podcast)
    podcast_99.should_receive(:title).and_return("MyString")
    podcast_99.should_receive(:site).and_return("MyString")
    podcast_99.should_receive(:feed).and_return("MyString")
    podcast_99.should_receive(:logo_file_name).and_return("MyString")
    podcast_99.should_receive(:logo_content_type).and_return("MyString")
    podcast_99.should_receive(:logo_file_size).and_return("MyString")

    assigns[:podcasts] = [podcast_98, podcast_99]
  end

  it "should render list of podcasts" do
    render "/podcasts/index.html.erb"
    response.should have_tag("tr>td", "MyString", 2)
    response.should have_tag("tr>td", "MyString", 2)
    response.should have_tag("tr>td", "MyString", 2)
    response.should have_tag("tr>td", "MyString", 2)
    response.should have_tag("tr>td", "MyString", 2)
    response.should have_tag("tr>td", "MyString", 2)
  end
end
