require 'app/models/podcast'

namespace :limecast do
  desc "generate encryption key"
  task :generate_encryption_key do
    `test ! -f #{RAILS_ROOT}/private/encryption_key.txt || cp #{RAILS_ROOT}/private/encryption_key.txt #{RAILS_ROOT}/private/encryption_key.txt.1`
    require 'openssl'
    encryption_key = [ OpenSSL::Random.random_bytes(60) ].pack('m*')
    File.open("#{RAILS_ROOT}/private/encryption_key.txt", 'w') do |f|
      f.write(encryption_key)
    end
  end
  
  desc "update all user scores"
  task :update_user_scores do
    User.all.each do |user|
      print "Updating score for user ##{user.id}... "
      user.calculate_score!
      puts user.score
    end
  end

  desc "create a statistic record for today"
  task :create_statistic => :environment do
    require 'net/ssh'
    # Can this part be done in Cap instead?
    begin
      remote = YAML.load(File.open("config/remote_server.yml"))[RAILS_ENV]

      podcast_google_ranks = []

      # Connect to remote server
      Net::SSH.start(remote['host'], remote['username'], :password => remote['password']) do |ssh|
        Podcast.all.each do |p| 
          puts "Getting Google ranking for '#{p.title}' (##{p.id})"
          
          title = p.title.delete("'")
          ssh.exec!(%Q!cd #{remote['dir']}/lib && ruby -r rubygems -r google_search_result -e "puts GoogleSearchResult.new('#{title}').rank('limecast.com')"!) do |channel, stream, data|
            podcast_google_ranks << data.strip.to_i
          end
        end
      end
      podcasts_on_google_first_page_count = podcast_google_ranks.reject(&:zero?).size
    rescue => e
      podcasts_on_google_first_page_count = 0
    end

    stat = Statistic.create({
      :podcasts_count                      => Podcast.all.size,
      :podcasts_found_by_admins_count      => Podcast.found_by_admin.size,
      :podcasts_found_by_nonadmins_count   => Podcast.found_by_nonadmin.size,
      :users_count                         => User.all.size,
      :users_confirmed_count               => User.confirmed.all.size,
      :users_unconfirmed_count             => User.unconfirmed.all.size,
      :users_admins_count                  => User.admins.all.size,
      :users_nonadmins_count               => User.nonadmins.all.size,
      :authors_count                       => User.authors.all.size,
      :reviews_by_admins_count             => Review.claimed.by_admin.all.size,
      :reviews_by_nonadmins_count          => Review.claimed.by_nonadmin.all.size,
      :reviews_count                       => Review.all.size,
      :podcasts_from_trackers_count        => Podcast.from_limetracker.all.size,
      :podcasts_with_buttons_count         => Podcast.find_all_by_button_installed(true).size,
      :podcasts_on_google_first_page_count => podcasts_on_google_first_page_count
    })
    
  end
end
