if File.exists? "config/settings.yml"
	Saneconf.conf.merge!(
		YAML.load_file("config/settings.yml")[Saneconf::RACK_ENV])
else
	Saneconf.conf.merge!(ENV)
end

db = URI Saneconf.conf['DATABASE_URL']
redis = URI Saneconf.conf['REDISTOGO_URL']

# Parse Redis connection settings.
Saneconf.conf['REDIS'] = {
	:host => redis.host,
	:port => redis.port,
	:password => redis.password,
	:db => redis.path[1..-1]
}

# If converting each setting to an integer, then a string leaves it equivalent
# to its original conversion to a string then it is an integer.
Saneconf.conf.each_key do |setting|
  if Saneconf.conf[setting].to_i.to_s == Saneconf.conf[setting].to_s
    Saneconf.conf[settings] = Saneconf.conf[setting].to_i
  end
end

Saneconf.conf.freeze
