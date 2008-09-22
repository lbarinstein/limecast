# Trying out factory girl. Check out the documentation here.
# http://github.com/thoughtbot/factory_girl/tree/master

Factory.define :podcast do |p|
  p.title    'Podcast'
  p.site     { Factory.next :site }
  p.feed_url { "#{Factory.next :site}/feed.xml" }
end

Factory.define :parsed_podcast, :class => Podcast do |p|
  p.title    'Podcast'
  p.state    'parsed'
  p.site     { Factory.next :site }
  p.feed_url { "#{Factory.next :site}/feed.xml" }
end

Factory.define :episode do |e|
  e.association  :podcast, :factory => :podcast
  e.summary      'This is the first episode of a show! w0000t'
  e.title        'Episode One'
  e.published_at Time.parse("Aug 1, 2008")
end

Factory.sequence :login do |n|
  "tester#{n}"
end
Factory.sequence :email do |n|
  "tester#{n}@podcasts.example.com"
end
Factory.sequence :site do |n|
  "http://myp#{'o'*n}dcast.com"
end

Factory.define :user do |u|
  u.login    { Factory.next :login }
  u.email    { Factory.next :email }
  u.password 'password'
  u.salt     'NaCl'
end

Factory.define :admin_user, :class => User do |u|
  u.login    'admin'
  u.email    'admin@podcasts.example.com'
  u.password 'password'
  u.salt     'NaCl'

  u.admin true
end

Factory.define :comment, :class => Comment do |c|
  c.association :commenter, :factory => :user
  c.association :episode, :factory => :episode
end

