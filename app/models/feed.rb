# == Schema Information
# Schema version: 20090306193031
#
# Table name: feeds
#
#  id          :integer(4)    not null, primary key
#  url         :string(255)
#  error       :string(255)
#  itunes_link :string(255)
#  podcast_id  :integer(4)
#  created_at  :datetime
#  updated_at  :datetime
#  state       :string(255)   default("pending")
#  bitrate     :integer(4)
#  finder_id   :integer(4)
#  format      :string(255)
#  xml         :text(16777215
#  ability     :integer(4)    default(0)
#

require 'open-uri'
require 'timeout'

class Feed < ActiveRecord::Base
  has_many :sources, :dependent => :destroy
  has_many :first_source, :class_name => 'Source', :limit => 1
  belongs_to :podcast
  belongs_to :finder, :class_name => 'User'

  after_save :remove_empty_podcast
  after_destroy { |f| f.finder.calculate_score! if f.finder }
  after_destroy :add_podcast_message

  validates_presence_of   :url
  validates_uniqueness_of :url
  validates_length_of     :url, :maximum => 1024

  named_scope :with_itunes_link, :conditions => 'feeds.itunes_link IS NOT NULL and feeds.itunes_link <> ""'
  named_scope :parsed, :conditions => {:state => 'parsed'}
  def pending?;     self.state == 'pending' || self.state.nil? end
  def parsed?;      self.state == 'parsed' end
  def failed?;      self.state == 'failed' end
  def blacklisted?; self.state == 'blacklisted' end

  attr_accessor :content

  define_index do
    indexes :url

    has :created_at, :podcast_id
  end

  def diagnostic_xml
    doc = Hpricot.XML(self.xml)
    doc.search("item").remove
    doc.to_s.gsub(/\n\s*\n/, "\n")
  end

  def as(type)
    case type
    when :torrent
      self.remixed_as_torrent
    when :magnet
      self.remixed_as_magnet
    else
      self.xml
    end
  end

  def remix_feed
    xml = self.xml.to_s.dup

    h = Hpricot(self.xml)
    (h / 'item').each do |item|
      enclosure     = (item % 'enclosure') || {}
      media_content = (item % 'media:content') || {}

      urls = [enclosure['url'], media_content['url']].compact.uniq
      urls.each do |url|
        s = self.sources.find_by_url(url)

        unless s.nil?
          new_url = yield s
          xml.gsub!(url, new_url) unless new_url.nil?
        end
      end
    end

    xml
  end

  def remixed_as_torrent
    remix_feed do |s|
      s.torrent_url if s.torrent?
    end
  end

  def remixed_as_magnet
    remix_feed do |s|
      s.magnet_url
    end
  end

  def itunes_url
    "http://www.itunes.com/podcast?id=#{self.itunes_link}"
  end

  def miro_url
    "http://subscribe.getmiro.com/?url1=#{self.url}"
  end

  def update_finder_score
    self.finder.calculate_score! if self.finder
  end

  def writable_by?(user)
    !!(user && user.active? && (self.finder_id == user.id || user.admin?))
  end

  def primary?
    self.podcast.primary_feed == self
  end

  def apparent_format
    self.sources.first.attributes['format'].to_s unless self.sources.blank?
  end

  def apparent_resolution
    self.sources.first.resolution unless self.sources.blank?
  end

  # takes the name of the Feed url (ie "http://me.com/feeds/quicktime-small" -> "Quicktime Small")
  def apparent_format_long
    url.split("/").last.titleize

    # Uncomment this to get the official format from the Source extension
    # ::FileExtensions::All[apparent_format.intern]
  end

  def formatted_bitrate
    self.bitrate.to_bitrate.to_s if self.bitrate and self.bitrate > 0
  end

  def just_created?
    self.created_at > 2.minutes.ago
  end

  protected

  def add_podcast_message
    podcast.add_message "The #{apparent_format} feed has been removed." if podcast
  end

  def remove_empty_podcast
    self.podcast.destroy if self.podcast && self.podcast.failed?
  end
end
