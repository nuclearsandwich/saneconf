<markdown>

Recently, the company I work for switched to using [Heroku][H] for application deployment. In the past I've always been hesitant toward "hosted solutions" but a combination of minimal time and the flexibility and power of Heroku's Celadon Cedar stack has brought me into contact with one such solution.

One of the first peculiarities/gotchas/side-effects of many of these hosted solutions is that they don't provide shell or ftp access. Nor can you write to the filesystem from your application. This caused us some interesting problems during the migration.

1. Rails convention dictates that `config/settings.yml`, `config/database.yml` and friends not be stored in source control and that we should store template files instead so developers are aware of setup specific configuration details. However, our inability to push files not in source control to Heroku leaves us unable to use the standard convention for configuration details. The way Heroku bypasses this leads to the next hurdle.

2. The whole point of Heroku is that you don't deal with IT, just your code. This means that you don't really care where your PostgreSQL database is or what port you use to connect to your Redis instance. But you still need to connect to those things! So what does Heroku do? They give you environment variables. `heroku run 'echo $DATABASE_URL'` returns a big long uri corresponding to your app's database. With this specific config variable, Heroku is kind enough to render a `database.yml` from it using erb. But it only works ActiveRecord compatible database.ymls, which is not all of them, believe it or not. (I'm looking at you Sequel) Inspect your Heroku config variables by running `heroku config` from an app directory. The amount of scary looking crap in there might surprise you!

You can even add your own config variables such as `MR_FANCY_PANTS=the_worlds_best_pants` with
`heroku config:add MR_FANCY_PANTS=sad_deep_inside ARTIST="Jonathan Coulton"` this command will expose both your variables to your code using Ruby's `ENV` hash.

In your code you'd get to it like this:
		#!ruby
		def controller_action
			if ENV['ARTIST'] == "Jonathan Coulton"
				@still_alive = true
			end
		end

But then this also has to work locally! So you need to do somethig like this:
		#!ruby
		def controller_action
			if (ENV['ARTIST'] || SETTINGS[:artist]) == "Jonathan Coulton"
				@still_alive = true
			end
		end

Alternatively, you could set up all these environment variables using a rake or thor task before launching your app but who wants to deal with that? My favorite solution to a problem is a coding solution.

And you have to do that *everywhere* you want to use a situation specific configuration. I don't know about you but that seems hacky, error prone, and repetitive to me. Smelly code, in other words. In working on my recent projects I've been studying a large number of small Ruby applications. Mostly Sinatra but some in Rails and Padrino as well. In all those apps, I never found a ubiquitously deployed solution for the configuration situation in a Heroku-style environment so I left it to simmer a few days and dealt with `ENV[:KEY] || SETTINGS['key']` all over my app. Then, over too much cold brew coffee I came up with a workable solution. While this is the very first time I've seen this solution in a web application. It actually comes from messing around in `irb` earlier in the week trying to alter prompt strings for vanity's sake.

Everyone open `irb` right now! Just go to a terminal and do it! Got it? Okay

`> IRB.conf`

You'll see how this inspired my solution later on. Or perhaps I'm not as brilliant as I think I am and it's obvious to you already (*likely*).

So let's say we're working on a lightweight Sinatra application and we know that it'll start simple and grow in complexity later on. Since we're smart we're going to namespace the whole thing under a module. Namely `Saneconf` Our skeleton looks like this:

		#!ruby
		require 'rubygems' # Only needed for Ruby 1.8
		require 'bundler'
		# After this line, I shouldn't even have to *think* about dependencies.
		Bundler.require
		
		# This is the initilization file for the Saneconf API. All set up, library
		# loading and application level settings are done here.
		module Saneconf
			# If there's a better/safer way to do this generically do let me know.
			# I haven't encountered a setup where this didn't work.
		  def Saneconf.root; Dir.pwd; end
		
			# This one is important so we set it early and use a constant.
		  # Set Rack environment if not specified.
		  RACK_ENV = ENV['RACK_ENV'] || "development"
		
			# Create an accessor to a module attribute which defaults to a
		  def Saneconf.conf; @conf_hash ||= Hash.new; end
		
		  # Handles initialization and preprocessing of application settings be they
		  # from Heroku's Environment or a local `settings.yml`.
		  require_relative 'config/setup.rb'
		
			class App < Sinatra::Base
				get '/' do
					"<h1>So nice to be sane again, eh? #{conf['ARTIST']}?</h1>"
				end
			end
		end

That looks cool and all, but what the hell is `config/setup.rb`? Answer: It's where the magic happens, let's go take a look:

		#!ruby
		if File.exists? "config/settings.yml"
			Saneconf.conf.merge!(
				YAML.load_file("config/settings.yml")[Saneconf::RACK_ENV])
			Saneconf.conf['RESQUE_SCHEDULE'] = 
				YAML.load_file("config/resque_schedule.yml")
		else
			Saneconf.conf.merge!(ENV)
		end
		
		db = URI Saneconf.conf['DATABASE_URL']
		redis = URI Saneconf.conf['REDISTOGO_URL']
		
		# Parse Postgres connection settings.
		Saneconf.conf['DATABASE'] = {
			:adapter => "#{db.scheme}ql", # Add a 'ql' cause ActiveRecord is stupid.
			:host => db.host,
			:port => db.port,
			:database => db.path[1..-1],
			:username => db.user,
			:password => db.password
		}
		
		# Parse Redis connection settings.
		Saneconf.conf['REDIS'] = {
			:host => redis.host,
			:port => redis.port,
			:password => redis.password,
			:db => redis.path[1..-1]
		}
		
		# Parse Resque Schedule YAML.
		if Saneconf.conf['RESQUE_SCHEDULE'].class == String
			Saneconf.conf['RESQUE_SCHEDULE'] = YAML.load Saneconf.conf['RESQUE_SCHEDULE']
		end
		
		Saneconf.conf.freeze

All this does is check for the existence of a `settings.yml` and load it's values into our (currently) empty configuration hash using an in-place `#merge!`. The reason we do this is because we very purposefully didn't supply a mutator `Saneconf.conf=` for our config hash. We don't *want* it to be overwritten later on. For the moment though we can change existing keys and add new ones. Next we handle all non-scalar configuration by parsing some of the scalar ones into hashes. Arrays or any other Ruby object could be placed in the `conf` hash. It just happens that Hashes are commonly used by libraries like ActiveRecord and the Ruby Redis interface for initialization. The reason I expand those here and not in place at point-of-use is mostly personal preference. All I ever want to see in the app is `conf['VARIABLE']` and I shouldn't have to think about it and whatever I'm trying to accomplish at that point in our app. Lastly, we call `#freeze` on the conf hash. This is a method every Ruby object has which makes it immutable, throwing an exception if an attempt is made to change it. This way, any of your fellow developers will know that whatever they're doing belongs in your application initialization code and not in the middle of your important code.


Hopefully this proves helpful, the example code is available on [GitHub][repo].

[H]: http://heroku.com
[repo]: http://github.com/nuclearsandwich/saneconf.git

</markdown>
