# == Schema Information
# Schema version: 20090507172652
#
# Table name: podcasts
#
#  id                   :integer(4)    not null, primary key
#  site                 :string(255)   
#  created_at           :datetime      
#  updated_at           :datetime      
#  category_id          :integer(4)    
#  clean_url            :string(255)   
#  owner_id             :integer(4)    
#  owner_email          :string(255)   
#  owner_name           :string(255)   
#  title                :string(255)   
#  primary_feed_id      :integer(4)    
#  has_previews         :boolean(1)    default(TRUE)
#  has_p2p_acceleration :boolean(1)    default(TRUE)
#  approved             :boolean(1)    
#  button_installed     :boolean(1)    
#  protected            :boolean(1)    
#  favorites_count      :integer(4)    default(0)
#  url                  :string(255)   
#  itunes_link          :string(255)   
#  state                :string(255)   default("pending")
#  bitrate              :integer(4)    
#  finder_id            :integer(4)    
#  format               :string(255)   
#  xml                  :text          
#  ability              :integer(4)    default(0)
#  generator            :string(255)   
#  xml_title            :string(255)   
#  description          :string(255)   
#  language             :string(255)   
#  logo_file_name       :string(255)   
#  logo_content_type    :string(255)   
#  logo_file_size       :string(255)   
#

require 'paperclip_file'
require 'open-uri'
require 'timeout'

class Podcast < ActiveRecord::Base
  # -- NEW STUFF FROM FEED
  has_many :sources, :dependent => :destroy
  has_one  :newest_source, :class_name => 'Source', :include => :episode, :order => "episodes.published_at DESC"
  has_one  :queued_feed, :dependent => :destroy
  belongs_to :owner, :class_name => 'User'
  belongs_to :finder, :class_name => 'User'
  after_destroy :update_finder_score
  named_scope :from_limetracker, :conditions => ["podcasts.generator LIKE ?", "%limecast.com/tracker%"]
  named_scope :with_itunes_link, :conditions => 'podcasts.itunes_link IS NOT NULL and podcasts.itunes_link <> ""'
  named_scope :parsed, :conditions => {:state => 'parsed'}
  named_scope :unclaimed, :conditions => "finder_id IS NULL"
  named_scope :claimed, :conditions => "finder_id IS NOT NULL"
  named_scope :found_by_admin, :include => :finder, :conditions => ["users.admin = ?", true]
  named_scope :found_by_nonadmin, :include => :finder, :conditions => ["users.admin = ? OR users.admin IS NULL", false]
  named_scope :sorted_by_bitrate_and_format, :order => "podcasts.bitrate ASC, podcasts.format ASC"

  def download_logo(link)
    file = PaperClipFile.new
    file.original_filename = File.basename(link)

    open(link) do |f|
      return unless f.content_type =~ /^image/

      file.content_type = f.content_type
      file.to_tempfile = with(Tempfile.new('logo')) do |tmp|
        tmp.write(f.read)
        tmp.rewind
        tmp
      end
    end

    self.attachment_for(:logo).assign(file)
  rescue OpenURI::HTTPError => e
  end

  # END NEW STUFF

  belongs_to :category
  belongs_to :primary_feed, :class_name => 'Feed' # deprecated
  has_many :favorites, :dependent => :destroy
  has_many :favoriters, :source => :user, :through => :favorites

  has_many :feeds  # deprecated
  #, :dependent => :destroy,
#           :after_add => :set_primary_feed_with_save, :after_remove => :set_primary_feed_with_save
  has_one  :first_feed, :class_name => 'Feed', :order => "feeds.created_at ASC", :include => :finder # deprecated
  has_many :episodes, :order => "published_at DESC", :dependent => :destroy
  has_one  :newest_episode, :class_name => 'Episode', :order => "published_at DESC"
  has_many :reviews, :through => :episodes, :conditions => "reviews.user_id IS NOT NULL"

  has_many :recommendations, :order => 'weight DESC'
  has_many :recommended_podcasts, :through => :recommendations, :source => :related_podcast

  has_many :taggings, :dependent => :destroy, :include => :tag, :order => 'tags.name ASC'
  has_many :tags, :through => :taggings, :order => 'tags.name ASC'
  has_many :badges, :source => :tag, :through => :taggings, :conditions => {:badge => true}, :order => 'name ASC'

  has_attached_file :logo,
                    :path => ":rails_root/public/podcast_:attachment/:id/:style/:basename.:extension",
                    :url  => "/podcast_:attachment/:id/:style/:basename.:extension",
                    :styles => { :square => ["85x85#", :png],
                                 :small  => ["170x170#", :png],
                                 :large  => ["300x300>", :png],
                                 :icon   => ["25x25#", :png],
                                 :thumb  => ["16x16#", :png] }

# deprecated
#  accepts_nested_attributes_for :feeds, :allow_destroy => true, :reject_if => proc { |attrs| attrs['url'].blank? } # deprecated

  named_scope :not_approved, :conditions => {:approved => false}
  named_scope :approved, :conditions => {:approved => true}
  named_scope :older_than, lambda {|date| {:conditions => ["podcasts.created_at < (?)", date]} }
  named_scope :parsed, :conditions => {:state => 'parsed'}
  named_scope :tagged_with, lambda { |*tags|
    # NOTE this does an OR search on the tags; needs to be refactored if all podcasts will include *all* tags
    # TODO This named_scope could definitely be simplified and optimized with some straight SQL
    tags = [tags].flatten.map { |t| Tag.find_by_name(t) }.compact
    podcast_ids = tags.map { |t| t.podcasts.map(&:id) }.flatten.uniq
    { :conditions => { :id => podcast_ids } }
  }
  named_scope :sorted, :order => "REPLACE(title, 'The ', '')"
  named_scope :popular, :order => "favorites_count DESC"
  named_scope :sorted_by_newest_episode, :include => :newest_episode, :order => "episodes.published_at DESC"

  attr_accessor :has_episodes, :last_changes
  attr_accessor_with_default :messages, []

  before_validation :sanitize_title
  before_validation :sanitize_url
  before_save :find_or_create_owner
#  before_save :set_primary_feed_without_save
  before_save :store_last_changes

  validates_presence_of   :title, :unless => Proc.new { |podcast| podcast.new_record? }
  validates_format_of     :title, :with => /[A-Za-z0-9]+/, :message => "must include at least 1 letter (a-z, A-Z)"
  validates_presence_of   :url
  validates_uniqueness_of :url
  validates_length_of     :url, :maximum => 1024

  # Search
  define_index do
    indexes :title, :site, :description, :owner_name, :owner_email, :url
    indexes owner.login, :as => :owner
    indexes episodes.title, :as => :episode_title
    indexes episodes.summary, :as => :episode_summary
    indexes tags.name, :as => :tag # includes badges

    has taggings.tag_id, :as => :tagged_ids
    has :created_at
  end

  def self.find_by_slug(slug)
    i = self.find_by_clean_url(slug)
    raise ActiveRecord::RecordNotFound if i.nil? || slug.nil?
    i
  end

  def self.found_by_admin
    Podcast.all.select { |p| p.found_by && p.found_by.admin? }
  end

  def self.found_by_nonadmin
    Podcast.all.select { |p| !p.found_by || !p.found_by.admin? }
  end

  def apparent_format
    sources.first.attributes['format'].to_s unless sources.blank?
  end

  def apparent_resolution
    sources.first.resolution unless sources.blank?
  end

  # takes the name of the Podcast url (ie "http://me.com/feeds/quicktime-small" -> "Quicktime Small")
  def apparent_format_long
    url.split("/").last.titleize

    # Uncomment this to get the official format from the Source extension
    # ::FileExtensions::All[apparent_format.intern]
  end
  
  def formatted_bitrate
    self.bitrate.to_bitrate.to_s if self.bitrate and self.bitrate > 0
  end

  def itunes_url
    "http://www.itunes.com/podcast?id=#{itunes_link}"
  end

  def miro_url
    "http://subscribe.getmiro.com/?url1=#{url}"
  end

  # XXX: Write spec for this
  def blacklist!
    Blacklist.create(:domain => url)
    update_attributes(:state => "blacklisted")
    destroy
  end

  # All taggings that are either badges or tags that have been user_tagging'ed.
  def claimed_taggings
    taggings.all.compact.reject { |t| !t.tag.badge? && t.user_taggings.claimed.empty? }
  end

  # All taggings that are tags that have NOT been user_tagging'ed.
  def unclaimed_taggings
    taggings.all.compact.reject { |t| t.tag.badge? || !t.user_taggings.claimed.empty? }
  end

  # All badges, and tags that have been user_tagging'ed.
  def claimed_tags
    claimed_taggings.map(&:tag)
  end

  # All badges, and tags that have NOT been user_tagging'ed.
  def unclaimed_tags
    unclaimed_taggings.map(&:tag)
  end

  def related_podcasts
    Recommendation.for_podcast(self).by_weight.first(5).map(&:related_podcast)
  end

  def found_by
    first_feed.finder rescue nil
  end

  def owned_by
    owner
  end

  def favorite_of?(user)
    user && user.favorite_podcasts.include?(self)
  end

  # deprecated
  # def description
  #   primary_feed.description
  # end

  def average_time_between_episodes
    return 0 if self.episodes.count < 2
    time_span = self.episodes.first.published_at - self.episodes.last.published_at
    time_span / (self.episodes.count - 1)
  end

  def clean_site
    self.site ? self.site.to_url : ''
  end

  def primary_feed_with_default
    set_primary_feed_with_save if primary_feed_without_default(true).nil?
    primary_feed_without_default(true)
  end
  alias_method_chain :primary_feed, :default

  def just_created?
    self.created_at > 2.minutes.ago
  end

  # deprecated
  # def logo(*args)
  #   primary_feed.logo(*args) if primary_feed
  # end
  # def logo?
  #   primary_feed.logo? if primary_feed
  # end

  def total_run_time
    self.episodes.sum(:duration) || 0
  end

  def to_param
    clean_url
  end

  def writable_by?(user)
    return true if editors.include?(user)
    return false
  end

  def user_is_owner?(user)
    return false if owner.nil? or user.nil?
    owner.id == user.id
  end

 # An array of users that tagged this podcast
 def taggers
   taggings.map { |t| t.users }.flatten.compact.uniq
 end

  # An array of users that may edit this podcast
  def editors
    return @editors if @editors
    @editors = returning([]) do |e|
      e << User.admins.all
      e << finder if finder && !protected?
      e << owner if owner && owner.confirmed?
      e.flatten!
      e.compact!
      e.reject!(&:passive?)
    end
    @editors
  end

  # Takes a string of space-delimited tags and tries to add them to the podcast's taggings.
  # Also takes an additional user argument, which will add a UserTagging to join the Tagging
  # with a User (to see which users added which tags).
  # Ex: podcast.tag_string = "funny, hilarious"
  # Ex: podcast.tag_string = "animated, kids", current_user
  def tag_string=(*args)
    args.flatten!
    v, user = args

    v.split.each do |tag_name|
      t = Tag.find_by_name(tag_name) || Tag.create(:name => tag_name)
      self.tags << t unless self.tags.include?(t)

      if user && user.is_a?(User)
        tagging = taggings(true).find_by_tag_id(t.id)
        tagging.users << user unless tagging.users.include?(user)
      end
    end
  end

  def tag_string
    self.tags.map(&:name).join(" ")
  end

  # These are additional badges that we don't keep as Tag/Taggings
  def additional_badges(reload=false)
    return @additional_badges if @additional_badges && !reload

    @additional_badges = returning [] do |ab|
      ab << language unless language.blank?

      if e = episodes.newest[0]
        ab << 'current' if e.published_at > 30.days.ago
        ab << 'stale'   if e.published_at <= 30.days.ago && e.published_at > 90.days.ago
        ab << 'archive' if e.published_at <= 90.days.ago
      end
    end
  end

  def new?
    created_at == updated_at
  end

  def notify_users
    if new?
      PodcastMailer.deliver_new_podcast(self)
    end
  end

  def add_message(msg)
    # TODO this could probably be a one-liner
    # TODID i will verify that making this method a one-liner is possible
    self.messages << msg
  end

  protected
  def sanitize_title
    # cache the xml_title or blank until next time
    self.title = xml_title.to_s if title.blank?

    desired_title = title
    # Second, sanitize "title"
    self.title.gsub!(/\(.*\)/, "") # Remove anything in parentheses
    self.title.sub!(/^[\s]*-/, "") # Remove leading dashes
    self.title.strip!              # Remove leading and trailing space

    # Increment the name until it's unique
    self.title = "#{title} 2" if Podcast.exists?(["title = ? AND id != ?", title, id.to_i])
    self.title.increment! while Podcast.exists?(["title = ? AND id != ?", title, id.to_i])

    add_message "There was another podcast with the same title, so we have suggested a new title." if title != desired_title

    return title
  end

  def sanitize_url
    if (title.blank? || title_changed?)
      self.clean_url = self.title.to_s.clone.strip # Remove leading and trailing spaces
      self.clean_url.gsub!(/[^A-Za-z0-9\s-]/, "")  # Remove all non-alphanumeric non-space non-hyphen characters
      self.clean_url.gsub!(/\s+/, '-')             # Condense spaces and turn them into dashes
      self.clean_url.gsub!(/\-{2,}/, '-')          # Replaces multiple sequential hyphens with one hyphen

      i = 1 # Number to attach to the end of the title to make it unique
      self.clean_url = "#{clean_url}-2" if Podcast.exists?(["clean_url = ? AND id != ?", clean_url, id.to_i])
      self.clean_url.increment! while Podcast.exists?(["clean_url = ? AND id != ?", clean_url, id.to_i])

      add_message "The podcast url has changed." if clean_url_changed?
    end

    return clean_url
  end

  def find_or_create_owner
    return true if (!self.owner_id.blank? || self.owner_email.blank?) && !self.owner_email_changed?

    self.owner = User.find_or_create_by_email(owner_email)

    return true
  end

  def set_primary_feed_without_save(obj=nil)
    self.primary_feed.id = feeds.first.id if primary_feed_without_default.nil? && feeds.size > 0
  end

  def set_primary_feed_with_save(obj=nil)
    update_attribute(:primary_feed, feeds.first) if primary_feed_without_default.nil? && feeds.size > 0
  end

  # Rails dirty objects stores the current changes only until the object is saved
  def store_last_changes
    @last_changes = changes
  end

  def update_finder_score
    finder.calculate_score! if finder
  end
end
