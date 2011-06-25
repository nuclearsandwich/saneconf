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
	:adapter => "#{db.scheme}ql",
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
