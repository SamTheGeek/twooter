require 'twitter_ebooks'

# This is an example bot definition with event handlers commented out
# You can define and instantiate as many bots as you like

class UserInfo
  attr_reader :username

  # @return [Integer] how many times we can pester this user unprompted
  attr_accessor :pesters_left

  # @param username [String]
  def initialize(username)
    @username = username
    @pesters_left = 1
  end
end

class MyBot < Ebooks::Bot
  attr_accessor :original, :model, :model_path

  # Configuration here applies to all MyBots
  def configure
    # Consumer details come from registering an app at https://dev.twitter.com/
    # Once you have consumer details, use "ebooks auth" for new access tokens
    self.consumer_key = 'OfQgPi1EOy9ujfuyDOZ03VBWR' # Your app consumer key
    self.consumer_secret = 'svvXXKjAbYrKdBYT5STY0bs4gufzSKINwtXnUUNHT1WJtsHiK3' # Your app consumer secret

    # Users to block instead of interacting with
    self.blacklist = []

    # Range in seconds to randomize delay when bot.delay is called
    self.delay_range = 1..6
    @userinfo = {}
  end

  def top100; @top100 ||= model.keywords.take(100); end
  def top20;  @top20  ||= model.keywords.take(20); end

  def on_startup
    model = Ebooks::Model.load("model/samthegeek.model")
    scheduler.every '12h' do
      tweet(model.make_statement(140))
      # Tweet something every 12 hours
      # See https://github.com/jmettraux/rufus-scheduler
    end
  end

  def on_message(dm)
    # Reply to a DM
    # reply(dm, "secret secrets")
    reply(dm, "👋 "+model.make_response(dm.text))
  end

  def on_follow(user)
    # Follow a user back
    follow(user.screen_name)
  end

  def on_mention(tweet)
    # Become more inclined to pester a user when they talk to us
    userinfo(tweet.user.screen_name).pesters_left += 1

    delay do
      # Reply to a mention
      reply(tweet, model.make_response(meta(tweet).mentionless, meta(tweet).limit))
    end
  end

  def on_timeline(tweet)
    return if tweet.retweeted_status?
    return unless can_pester?(tweet.user.screen_name)

    tokens = Ebooks::NLP.tokenize(tweet.text)

    interesting = tokens.find { |t| top100.include?(t.downcase) }
    very_interesting = tokens.find_all { |t| top20.include?(t.downcase) }.length > 2

    delay do
      if very_interesting
        favorite(tweet) if rand < 0.5
        retweet(tweet) if rand < 0.1
        if rand < 0.01
          userinfo(tweet.user.screen_name).pesters_left -= 1
          reply(tweet, model.make_response(meta(tweet).mentionless, meta(tweet).limit))
        end
      elsif interesting
        favorite(tweet) if rand < 0.05
        if rand < 0.001
          userinfo(tweet.user.screen_name).pesters_left -= 1
          reply(tweet, model.make_response(meta(tweet).mentionless, meta(tweet).limit))
        end
      end
    end
  end

  def on_favorite(user, tweet)
    # Follow user who just favorited bot's tweet
    if can_follow?(tweet.user.screen_name)
      super(tweet)
    else
      log "Unfollowing @#{tweet.user.screen_name}"
      twitter.unfollow(tweet.user.screen_name)
    end
  end

  def on_retweet(tweet)
    # Follow user who just retweeted bot's tweet
    if can_follow?(user.screen_name)
      follow(user.screen_name)
    else
      log "Not following @#{user.screen_name}"
    end
  end

  # Find information we've collected about a user
 # @param username [String]
 # @return [Ebooks::UserInfo]
 def userinfo(username)
   @userinfo[username] ||= UserInfo.new(username)
 end

 # Check if we're allowed to send unprompted tweets to a user
 # @param username [String]
 # @return [Boolean]
 def can_pester?(username)
   userinfo(username).pesters_left > 0
 end

 # Only follow our original user or people who are following our original user
 # @param user [Twitter::User]
 def can_follow?(username)
   @original.nil? || username.casecmp(@original) == 0 || twitter.friendship?(username, @original)
 end

end

# Make a MyBot and attach it to an account
MyBot.new("samthegeebooks") do |bot|
  bot.access_token = "754460397550333952-bqnAN5ahZPDDEOnopYwYmpSARZPhR7o" # Token connecting the app to this account
  bot.access_token_secret = "9MzFRZ1z6GYhLvFTIZL0s9pNsKm9mDhLbvEhCbPgYMeLU" # Secret connecting the app to this account
  bot.original = "samthegeek"
end
