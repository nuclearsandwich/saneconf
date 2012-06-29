require 'bundler'
# After this line, I shouldn't even have to *think* about dependencies.
Bundler.require

# This is the initilization file for the Saneconf API. All set up, library
# loading and application level settings are done here.
module Saneconf
  # If there's a better/safer way to do this generically do let me know.
  # I haven't encountered a setup where this didn't work.
  def Saneconf.root
    Dir.pwd
  end

  # This one is important so we set it early and use a constant.
  # Set Rack environment if not specified.
  RACK_ENV = ENV['RACK_ENV'] || "development"

  # Create an accessor to a module attribute which defaults to an empty
  # hash.
  def Saneconf.conf
    @conf_hash ||= Hash.new
  end

  # Handles initialization and preprocessing of application settings be they
  # from Heroku's Environment or a local `settings.yml`.
  require_relative 'config/setup.rb'

  # Establish Redis connection.
  def Saneconf.redis
    @redis ||= Redis.new conf['REDIS']
  end

  class App < Sinatra::Base
    get '/'  do
      <<-HTML
<h1>So nice to be sane again, eh? #{Saneconf.conf['ARTIST']}</h1>
<p>The value of #{Saneconf.conf['NUMBER']} (mod #{Saneconf.conf['BASE']}) is
      #{Saneconf.conf['NUMBER'] % Saneconf.conf['BASE']}</p>
      HTML
    end
  end
end
